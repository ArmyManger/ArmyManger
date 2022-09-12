/*--0：数据表说明
#t_member_total=会员合计临时表
#t_ponint_total=积分合计临时表
#t_transaction_total=交易合计临时表
#pools=券池codeNo表
#member_pools=会员关联券池codeNo表
数据合并的临时表，使用换成数据表保存数据。
--*/
--1：手动导入数据
--2：处理会员数据
--2.1查询需要处理的会员数据并排序，从券池获取codeNo。
USE [crm_Import]

select * into #t_member_total from (
select  row_number() over(order by 卡号) as number,* from
(
 select * from t_member1
 union all
 select * from t_member2 
) tmp ) as tmps

GO
--生成会员关联的券池临时表 
select * into #pools from (select top (select COUNT(1) from #t_member_total) 
 row_number() over(order by id) as number,* from crm_wathet_codenopool.dbo.t_Pool_001) as pools

 GO
--删除券池表
--delete from crm_wathet_codenopool.dbo.t_Pool_001 where CodeNo in (select codeno from #member_pool)
--关联会员和券池生成临时表 
create table #member_pools
(
    ID  int IDENTITY (1,1) not null,
	number int,
    memberNo nvarchar(50),   
    CodeNo nvarchar(50),
	mobile nvarchar(50),
	mallName nvarchar(50),
	levelName nvarchar(50),
);
--设置自增开始字段,从会员表取到最后一个自增长数据生成一条假数据，后续数据以这个自增长为准。
SET IDENTITY_INSERT #member_pools ON
INSERT INTO #member_pools (ID) VALUES ((select IDENT_CURRENT ('t_MemberCrm_Test'))) 
SET IDENTITY_INSERT #member_pools OFF 
GO
--增加关联数据
insert into  #member_pools (number,memberNo,codeNo,mobile,mallName,levelName)
select  #t_member_total.number,卡号 as memberNo,codeNo,手机 as mobile,开卡商场,会员等级 from #t_member_total,#pools where #t_member_total.number = #pools.number

GO
--3：更新数据
--3.1更新积分
select * into #t_ponint_total from 
(
 select * from t_point1 
 union 
 select * from t_point2  
 union 
 select * from t_point3  
) as tmp

alter table  #t_ponint_total  add  memberId int; --新增一列保存memberId
go
UPDATE #t_ponint_total 
        SET 会员卡号=T2.VALUE,memberId=T2.ID 
FROM #t_ponint_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE,ID FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.会员卡号 

--3.2更新交易
select * into #t_transaction_total from 
(
 select * from transaction1 
 union 
 select * from transaction2
 union 
 select * from transaction3
) as tmp
alter table  #t_transaction_total  add  memberId  int; --新增一列保存memberId 
go
UPDATE #t_transaction_total 
  SET 会员卡号=T2.VALUE,memberId =T2.ID 
FROM #t_transaction_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE,ID FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.会员卡号
 
--3.3更新会员
UPDATE #t_member_total 
        SET 卡号=T2.VALUE 
FROM #t_member_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.卡号
GO
--4保存到会员表、积分表、交易表用于同步到业务库中
INSERT INTO dbo.t_MemberCrm_Test(isCheck,memberNo,nickName,realName,gender,birth,logo,mobile,isValidMobile,email,
isValidEmail,cardType,cardNo,isValidCard,levelID,levelName,mall,mallCode,mallName,
isLockPoint,pointAmount,pointAmountValue,pointReward,pointRedemption,pointExpire,nextExpirePoint,nextExpireTime,country,memberPwd,isAllowMarket,sortNo,createTime,updateTime,valid,deleted,createrId,createrName)
select 1,mt.卡号,mt.手机,mt.姓名,ISNULL(mt.性别,0),'1900-01-01 00:00:00.000',null,mt.手机,1,mt.邮箱,
  case when mt.邮箱 IS NULL then 1 else 0 end,
1,NULL,0,levels.Id,levels.levelName,mall.id,mall.mallCode,mall.mallName,0,null,mt.当前积分,0,0,0,0,'1900-01-01 00:00:00.000','中国',null,1,
0,getdate(),getdate(),1,0,0,'Import' from  #t_member_total mt
left join saas_MainData.dbo.t_Info_Level levels on mt.会员等级+'会员' = levels.levelName 
left join saas_MainData.dbo.t_Mall mall on mall.mallName = mt.开卡商场 
--保存会员等级记录
INSERT INTO dbo.t_MemberCrm_LevelRecord_Test(memberId,memberNo,memberName,levelId,levelName,valid_begin,valid_end,
sendTime,recordType,recordTypeName,description,sortNo,createTime,updateTime,valid,deleted,createrID,createrName)
select mp.ID,mp.CodeNo,mp.mobile,levels.Id,levels.levelName,levels.startTime,dateadd(day,levels.validTime*30,levels.startTime),
GETDATE(),1,'升级','',1000,GETDATE(),GETDATE(),1,0,0,'Import' from  #member_pools mp 
left join saas_MainData.dbo.t_Info_Level levels on mp.levelName+'会员' = levels.levelName  where mp.CodeNo is not null 

--增加初始账积分
INSERT INTO dbo.t_Crm_Point_Test(codeNo,memberID,memberNo,memberNickName,mobile,pointFrom,pointFromName,
partnerId,partnerCode,partnerName,fromID,fromNo,fromName,fromActionID,transAmount,pointAmount,pointSurplus,balanceAmount,
isRedemptionMath,redemptionLog,isExpireMath,proTime,expiryTime,doublingNumber,eventTag,runLog,shop,mall,
mallCode,mallName,isrefund,refundTime,errorStatus,
errorStatusName,errorStatusMsg,description,sortNo,createTime,updateTime,valid,deleted,createrId,createrName) 
select NEWID(),memberPools.ID,memberPools.CodeNo,memberPools.mobile,memberPools.mobile,403,'外部接口',3,'CRM','CRM系统',
0,'','',0,0, member.当前积分,case when member.当前积分 > 0 then member.当前积分 else 0 end,0,0,'',0,GETDATE(),'2022-06-30 23:59:59.00',1,'','',0,mall.id,mall.mallCode,mall.mallName,0,'1900-01-01 00:00:00.000',1,'正常','正常',
'初始账',1000,GETDATE(),GETDATE(),1,0,0,'Import'  from #t_member_total member
inner join #member_pools memberPools on member.卡号 = memberPools.CodeNo
left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.开卡商场
 where member.卡号 = memberPools.CodeNo and memberPools.CodeNo is not null 

--增加积分
INSERT INTO dbo.t_Crm_Point_Test(codeNo,memberID,memberNo,memberNickName,mobile,pointFrom,pointFromName,partnerId,partnerCode,partnerName,
fromID,fromNo,fromName,fromActionID,transAmount,pointAmount,pointSurplus,balanceAmount,
isRedemptionMath,redemptionLog,isExpireMath,proTime,expiryTime,doublingNumber,eventTag,runLog,shop,mall,
mallCode,mallName,isrefund,refundTime,errorStatus,
errorStatusName,errorStatusMsg,sortNo,createTime,updateTime,valid,deleted,createrId,createrName) 
select NEWID(),member.ID,member.CodeNo,member.mobile,member.mobile,403,'外部接口',3,'CRM','CRM系统',
0,'','',0,0, point.增减积分,0,0,
0,'',0,GETDATE(),'2022-06-30 23:59:59.00',1,'','',0,mall.id,mall.mallCode,mall.mallName,0,'1900-01-01 00:00:00.000',1,'正常','正常',
1000,GETDATE(),GETDATE(),1,0,0,'Import'  from #t_ponint_total point,#member_pools member
left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.mallName
 where point.会员卡号 = member.CodeNo
--增加交易
INSERT INTO dbo.t_Crm_Transaction_Test(memberId,memberName,memberCodeNo,mobile,
ticketNo,oriTicketNo,amount,amountReal,currency,paymentType,isPointMath,pointHistoryCodeNo,
pointMessage,partnerId,partnerCode,partnerName,transTime,uploadTime,transDate,isrefund,refundTime,
eventTag,shopId,shopCode,shopName,mallId,mallCode,mallName,errorStatus,errorStatusName,errorStatusMsg,fromId,doublingNumber,description,
sortNo,createTime,updateTime,valid,deleted,createrId,createrName)
 SELECT member.ID,'昵称',member.CodeNo,member.mobile,
 trans.Mallcoo单号,trans.Mallcoo单号,trans.消费金额,trans.消费金额, 'CNY',trans.支付方式,1,NEWID(),
 0,3,'CRM','CRM系统',GETDATE(),GETDATE(),CONVERT(varchar(8),GETDATE(),112),0, '1900-01-01 00:00:00.000',
 NEWID(),trans.Shopid,trans.ShopCode,trans.商户,mall.id,mall.mallCode,mall.mallName,1,'正常','正常',0,0,'',
 1000,GETDATE(),GETDATE(),1,0,0,'Import'
 FROM  #t_transaction_total trans,#member_pools member 
 left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.mallName 
 where trans.会员卡号 = member.CodeNo
  
--删除临时表
--drop table #t_member_total
--drop table #t_ponint_total
--drop table #t_transaction_total
--drop table #pools
--drop table #member_pools  

--select * from  #t_member_total
--select * from  #t_ponint_total
--select * from  #t_transaction_total
--select * from  #pools
--select * from  #member_pools  

