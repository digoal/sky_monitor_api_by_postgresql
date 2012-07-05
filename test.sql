-- 测试
-- 1.插入测试的服务和模块信息
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (1,'测试app1',1,'测试模块1','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (2,'测试app2',2,'测试模块2','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (3,'测试app3',3,'测试模块3','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (3,'测试app3',4,'测试模块4','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (3,'测试app3',5,'测试模块5','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());
insert into srv_info (appid,appname,modid,modname,department,dev,dev_phone,pm,pm_phone,op,op_phone,deployaddr,keepalive,status,comment,crt_time) values (4,'测试app4',6,'测试模块6','运维','digoal.zhou',123,'digoal.zhou',123,'digoal.zhou',123,'三墩',true,'在线','测试',now());

-- 插入测试的模块间依赖关系信息
insert into srv_depend(modid,depend_modid,crt_time) values (1,3,now());
insert into srv_depend(modid,depend_modid,crt_time) values (2,3,now());
insert into srv_depend(modid,depend_modid,crt_time) values (4,1,now());
insert into srv_depend(modid,depend_modid,crt_time) values (5,4,now());
insert into srv_depend(modid,depend_modid,crt_time) values (5,6,now());

-- 插入鉴权信息
insert into srv_monitor_grant (modid,submodid,addr,crt_time) values (3,0,'172.16.3.39',now());


-- 2.应用调用API函数测试
-- 在172.16.3.39上执行如下,
-- 因为modid = 1未给172.16.3.39服务器鉴权, 所以keepalive报错.
test=# select * from keepalive(1,0);
NOTICE:  modid:1 and submodid:0 no granted with ip:172.16.3.39, please check or grant it with above ip.
 keepalive 
-----------
         1
(1 row)
-- modid = 3给172.16.3.39服务器做了鉴权, 因此可以插入.
test=# select * from keepalive(3,0);
 keepalive 
-----------
         0
(1 row)
test=# select * from srv_keepalive;
 id | modid |      last_time      
----+-------+---------------------
  1 |     3 | 2012-04-21 23:11:55
(1 row)

-- 告警测试
test=# select * from app_api(3,0,1,'ERR','请致电运维人员') ;
 app_api 
---------
       0
(1 row)

test=# select * from srv_mq;
 id | modid | submodid | code | appcode |      info      | nagios_reads |      crt_time       | mod_time | recover_time 
----+-------+----------+------+---------+----------------+--------------+---------------------+----------+--------------
  1 |     3 |        0 |    1 | ERR     | 请致电运维人员 |            0 | 2012-07-05 16:41:39 |          | 
(1 row)

-- 3.使用nagios获取告警测试, 由于1,2号模块直接依赖3号模块, 4,5号模块间接依赖3号模块, 所以会在依赖信息中报出.
test=# select * from nagios_get_mq();
                                          nagios_get_mq                                          
-------------------------------------------------------------------------------------------------
 -- 异常模块信息: 格式:返回值,异常开始时间,部门,app名,模块名,子模块ID,应用错误代码,应用输出信息.
 1,2012-07-05 16:41:39,运维,测试app3,测试模块3,0,ERR,请致电运维人员
 -- 依赖这些异常模块的模块信息:
 运维,测试app1,测试模块1
 运维,测试app2,测试模块2
 运维,测试app3,测试模块4
 运维,测试app3,测试模块5
(7 rows)

-- 使用nagios获取keepalive超时或未开启的信息.
test=# select * from nagios_keepalive('1 sec');
                             nagios_keepalive                             
--------------------------------------------------------------------------
 -- 列出在srv_info表中开启了keepalive, 但是应用未调用keepalive函数的记录.
 -- 格式: 部门,应用名,模块名,子模块ID.
 运维,测试app1,测试模块1,0
 运维,测试app2,测试模块2,0
 运维,测试app3,测试模块4,0
 运维,测试app3,测试模块5,0
 运维,测试app4,测试模块6,0
 -- 列出超时的记录, 有则返回
 运维,测试app3,测试模块3,0
(9 rows)

-- 4.恢复正常测试.
test=# select * from app_api(3,0,0,'NORMAL','') ;
 app_api 
---------
       0
(1 row)
-- srv_mq中模块3的记录将移动到srv_mq_history表中.因此在此检查mq将不会报出异常
test=# select * from nagios_get_mq();
 nagios_get_mq 
---------------
 NORMAL
(1 row)
-- 检查srv_mq_history表, 信息已经记录, 包括恢复时间信息.
test=# select * from srv_mq_history ;
 id | modid | submodid | code | appcode |      info      | nagios_reads |      crt_time       |      mod_time       |    recover_time     
----+-------+----------+------+---------+----------------+--------------+---------------------+---------------------+---------------------
  1 |     3 |        0 |    1 | ERR     | 请致电运维人员 |            9 | 2012-07-05 16:41:39 | 2012-07-05 16:48:23 | 2012-07-05 16:48:23
(1 row)


-- # Author : Digoal zhou
-- # Email : digoal@126.com
-- # Blog : http://blog.163.com/digoal@126/