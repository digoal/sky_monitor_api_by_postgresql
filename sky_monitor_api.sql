-- 服务信息表
create table srv_info (
id serial primary key, -- 主键
appid int not null, -- 应用ID, 由运维分配
appname text not null, -- 应用名称描述
modid int not null, -- 应用ID中的模块ID, 由运维统一分配 
modname text not null, -- 模块名称描述
submodid int default 0 not null, -- 0为初始子模块ID, 如果同样的模块运行在多台服务器上, 或一台服务器上运行多个同样的模块. 应该分配不同的子模块号, 以区分监控信息
department text not null, -- 模块所属部门, 从直接所属部门一直追溯到一级部门
dev text not null, -- 开发者
dev_phone numeric not null, -- 开发者联系电话
pm text not null, -- 项目经理
pm_phone numeric not null, -- 项目经理联系电话
op text not null, -- 运维人员
op_phone numeric not null, -- 运维联系电话
deployaddr text not null, -- 该模块部署在什么地方, 多机房部署的应该都写上
keepalive boolean not null, -- 模块心跳监控开关, 表示监控程序是否需要主动探测该模块的keepalive状态
status text not null, -- 模块维护状态, 在维, 下线, 未知等
comment text not null, -- 备注
online_time timestamp(0) without time zone, -- 模块上线时间
offline_time timestamp(0) without time zone, -- 模块下线时间
crt_time timestamp(0) without time zone not null, -- 记录创建时间
mod_time timestamp(0) without time zone , -- 记录修改时间
unique(modid,submodid)
);

-- 服务的模块依赖关系表
create table srv_depend (
modid int not null, -- 应用ID中的模块ID, 由运维分配
submodid int default 0 not null,
depend_modid int not null, -- 该模块直接依赖哪些模块才可以正常运行
crt_time timestamp(0) without time zone not null, -- 记录创建时间
mod_time timestamp(0) without time zone , -- 记录修改时间
foreign key (modid,submodid) references srv_info(modid,submodid),
foreign key (depend_modid,submodid) references srv_info(modid,submodid),
unique (modid,depend_modid),
check (submodid=0)  -- 本表只记录初始子模块ID
);

-- 鉴权表, 不在这个表里面的客户端发起的请求将报错, 应该包括模块中所有子模块ID的信息.
create table srv_monitor_grant (
id serial primary key, -- 主键
modid int not null, -- 模块ID, 由运维分配
submodid int not null,
addr inet not null, -- 将响应这些modid从这些IP发起的请求, 防止程序中配置错误导致监控信息有误.
crt_time timestamp(0) without time zone not null, -- 记录创建时间
mod_time timestamp(0) without time zone, -- 记录修改时间
foreign key (modid,submodid) references srv_info(modid,submodid),
unique (modid,submodid,addr)
);

-- keepalive表
create table srv_keepalive (
id serial8 primary key, -- 主键
modid int not null, -- 模块ID, 由运维分配
submodid int not null, -- 0为初始子模块ID, 如果同样的模块运行在多台服务器上, 或一台服务器上运行多个同样的模块. 应该分配不同的子模块号, 以区分监控信息
last_time timestamp(0) without time zone not null, -- 记录创建时间, 也就是最后一次keepalive消息发送过来的时间.
foreign key (modid,submodid) references srv_info(modid,submodid),
unique (modid,submodid)
);

-- 异常队列表
create table srv_mq (
id serial8 primary key, -- 主键
modid int not null, -- 应用ID中的模块ID, 由运维分配
submodid int not null, -- 0为初始子模块ID, 如果同样的模块运行在多台服务器上, 或一台服务器上运行多个同样的模块. 应该分配不同的子模块号, 以区分监控信息
code int not null, -- 返回值, 1, 2, 由运维约定, 0 正常, 1警告, 2异常.
appcode text not null, -- 程序返回的错误代码, 由程序定义, 但是同样的错误必须使用相同的错误代码, 避免多次记录同一个错误.
info text not null, -- 返回信息, 程序输出的错误信息等.
nagios_reads int default 0 not null, -- 该消息被nagios读取的次数, 每次nagios读取到消息后自增1
crt_time timestamp(0) without time zone not null, -- 记录创建时间, 也就是故障发生的时间
mod_time timestamp(0) without time zone, -- 记录修改时间, 每次nagios读取后更新这个时间.
recover_time timestamp(0) without time zone, -- 故障恢复时间, 恢复后记录移至srv_mq_history表.
foreign key (modid,submodid) references srv_info(modid,submodid)
);

-- 异常队列历史表
create table srv_mq_history (
id int8 primary key, -- 主键
modid int not null, -- 应用ID中的模块ID, 由运维分配
submodid int not null, -- 0为初始子模块ID, 如果同样的模块运行在多台服务器上, 或一台服务器上运行多个同样的模块. 应该分配不同的子模块号, 以区分监控信息
code int not null, -- 返回值, 1, 2, 由运维约定, 0 正常, 1警告, 2异常.
appcode text not null, -- 程序返回的错误代码, 由程序定义, 但是同样的错误必须使用相同的错误代码, 避免多次记录同一个错误.
info text not null, -- 返回信息, 程序输出的错误信息等.
nagios_reads int default 0 not null, -- 该消息被nagios读取的次数, 每次nagios读取到消息后自增1
crt_time timestamp(0) without time zone not null, -- 记录创建时间, 也就是故障发生的时间
mod_time timestamp(0) without time zone, -- 记录修改时间, 每次nagios读取后更新这个时间.
recover_time timestamp(0) without time zone, -- 故障恢复时间
foreign key (modid,submodid) references srv_info(modid,submodid)
);

-- 程序接口函数keepalive,间隔一定的时间由程序调用,表示与数据库通讯正常,并且表示程序的监控模块正常.
create or replace function keepalive(i_modid int, i_submodid int) returns int as $$
declare
v_addr inet;
begin
-- 判断鉴权
select inet_client_addr() into v_addr;
perform 1 from srv_monitor_grant where modid = i_modid and submodid = i_submodid and addr = v_addr;
if not found then
  raise notice 'modid:% and submodid:% no granted with ip:%, please check or grant it with above ip.',i_modid,i_submodid,v_addr;
  raise exception 'err';
end if;
-- 如果不存在则插入keepalive信息
perform 1 from srv_keepalive where modid = i_modid and submodid = i_submodid;
if not found then
  insert into srv_keepalive (modid,submodid,last_time) values (i_modid, i_submodid, now());
  return 0;
end if;
-- 如果存在则更新keepalive信息
update srv_keepalive set last_time = now() where modid = i_modid and submodid = i_submodid;
return 0;
-- 异常处理
exception 
when others then
  return 1;
end;
$$ language plpgsql;

-- 程序接口函数,异常以及恢复时由程序调用.
create or replace function app_api(i_modid int, i_submodid int, i_code int,i_appcode text,i_info text) returns int as $$
declare
v_addr inet;
begin
-- 判断鉴权
select inet_client_addr() into v_addr;
perform 1 from srv_monitor_grant where modid = i_modid and submodid = i_submodid and addr = v_addr;
if not found then
  raise notice 'modid:% and submodid:% no granted with ip:%, please check or grant it with above ip.',i_modid,i_submodid,v_addr;
  raise exception 'err';
end if;
case i_code
when 0 then -- 表示恢复,移动该记录到历史表
  insert into srv_mq_history (id,modid,submodid,code,appcode,info,nagios_reads,crt_time,mod_time,recover_time) 
    select id,modid,submodid,code,appcode,info,nagios_reads,crt_time,now(),now() from srv_mq where modid=i_modid and submodid=i_submodid;
  delete from srv_mq where modid=i_modid and submodid=i_submodid;
when 1, 2 then -- 表示 1警告 , 2异常
  -- 判断是否已经存在相同的告警, 存在则不做任何动作, 不存在则插入
  perform 1 from srv_mq where modid=i_modid and submodid=i_submodid and appcode=i_appcode;
  if not found then
    insert into srv_mq (modid,submodid,code,appcode,info,crt_time)
      values (i_modid,i_submodid,i_code,i_appcode,i_info,now());
  end if;
else -- 非法代码
  raise notice 'the code:% is not assigned, please use 0,1,2.', i_code;
  raise exception 'err';
end case;
return 0;
-- 异常处理
exception 
when others then
  return 1;
end;
$$ language plpgsql;


-- nagios调用的函数, 根据输入的时间间隔参数查询是否有keepalive异常的记录.
create or replace function nagios_keepalive (i_interval interval) returns setof text as $$
declare
begin
-- 列出在srv_info表中开启了keepalive, 但是应用未调用keepalive函数的记录.
-- 格式: 部门,应用名,模块名,子模块ID
return next '-- 列出在srv_info表中开启了keepalive, 但是应用未调用keepalive函数的记录.';
return next '-- 格式: 部门,应用名,模块名,子模块ID.';
return query select department||','||appname||','||modname||','||submodid from srv_info where keepalive is true and (modid,submodid) not in (select modid,submodid from srv_keepalive);
-- 列出超时的记录, 有则返回部门,app名,模块名的信息
return next '-- 列出超时的记录, 有则返回';
perform 1 from srv_keepalive where now() > (last_time+i_interval) and (modid,submodid) in (select modid,submodid from srv_info where keepalive is true);
if found then 
  return query select department||','||appname||','||modname||','||submodid from srv_info where (modid,submodid) in (select modid,submodid from srv_keepalive where now() > (last_time+i_interval) and (modid,submodid) in (select modid,submodid from srv_info where keepalive is true));
  return ;
end if;
-- 正常则返回NORMAL
return next 'NORMAL';
return ;
exception
when others then
-- 异常返回ERROR
  return next 'ERROR';
  return ;
end;
$$ language plpgsql;
-- nagios可根据NORMAL和ERROR判断告警状态.


-- nagios读取mq信息,返回异常的模块信息, 并返回依赖这些异常模块的模块信息.
create or replace function nagios_get_mq () returns setof text as $$
declare
begin
perform 1 from srv_mq limit 1;
if found then
-- 返回异常的模块信息,格式:返回值,异常开始时间,部门,app名,模块名,应用错误代码,应用输出信息.
return next '-- 异常模块信息: 格式:返回值,异常开始时间,部门,app名,模块名,子模块ID,应用错误代码,应用输出信息.';
return query select t1.code::text||','||t1.crt_time||','||t2.department||','||t2.appname||','||t2.modname||','||t2.submodid||','||t1.appcode||','||t1.info from srv_mq t1,srv_info t2 where t1.modid=t2.modid;
-- 更新nagios已读取次数字段.
update srv_mq set nagios_reads=nagios_reads+1;
return next '-- 依赖这些异常模块的模块信息:';
-- 1. 返回直接 以及 间接依赖这些异常模块的模块信息.格式:部门,app名,模块名 (如果因为模块相互依赖的情况导致递归有问题, 则和下面的只返回直接依赖的返回替换)
return query with recursive t1 as
(
select modid, department||','||appname||','||modname as res_info from srv_info where modid in (select modid from srv_depend where depend_modid in (select modid from srv_mq group by modid))
union
select t2.modid, t2.department||','||t2.appname||','||t2.modname as res_info from srv_info t2 join srv_depend t3 on (t2.modid=t3.modid) join t1 on (t3.depend_modid=t1.modid)
)
select res_info from t1;
-- 2. 仅返回直接依赖这些异常模块的模块信息.格式:部门,app名,模块名
-- return query select department||','||appname||','||modname from srv_info where modid in (select modid from srv_depend where depend_modid in (select modid from srv_mq group by modid));
return;
end if;
-- 正常则返回NORMAL
return next 'NORMAL';
return;
exception 
when others then
-- 异常返回ERROR
return next 'ERROR';
return;
end;
$$ language plpgsql;
-- nagios可根据NORMAL和ERROR判断告警状态.


-- # Author : Digoal zhou
-- # Email : digoal@126.com
-- # Blog : http://blog.163.com/digoal@126/