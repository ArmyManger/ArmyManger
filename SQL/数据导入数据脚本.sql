/*--0�����ݱ�˵��
#t_member_total=��Ա�ϼ���ʱ��
#t_ponint_total=���ֺϼ���ʱ��
#t_transaction_total=���׺ϼ���ʱ��
#pools=ȯ��codeNo��
#member_pools=��Ա����ȯ��codeNo��
���ݺϲ�����ʱ��ʹ�û������ݱ������ݡ�
--*/
--1���ֶ���������
--2�������Ա����
--2.1��ѯ��Ҫ����Ļ�Ա���ݲ����򣬴�ȯ�ػ�ȡcodeNo��
USE [crm_Import]

select * into #t_member_total from (
select  row_number() over(order by ����) as number,* from
(
 select * from t_member1
 union all
 select * from t_member2 
) tmp ) as tmps

GO
--���ɻ�Ա������ȯ����ʱ�� 
select * into #pools from (select top (select COUNT(1) from #t_member_total) 
 row_number() over(order by id) as number,* from crm_wathet_codenopool.dbo.t_Pool_001) as pools

 GO
--ɾ��ȯ�ر�
--delete from crm_wathet_codenopool.dbo.t_Pool_001 where CodeNo in (select codeno from #member_pool)
--������Ա��ȯ��������ʱ�� 
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
--����������ʼ�ֶ�,�ӻ�Ա��ȡ�����һ����������������һ�������ݣ��������������������Ϊ׼��
SET IDENTITY_INSERT #member_pools ON
INSERT INTO #member_pools (ID) VALUES ((select IDENT_CURRENT ('t_MemberCrm_Test'))) 
SET IDENTITY_INSERT #member_pools OFF 
GO
--���ӹ�������
insert into  #member_pools (number,memberNo,codeNo,mobile,mallName,levelName)
select  #t_member_total.number,���� as memberNo,codeNo,�ֻ� as mobile,�����̳�,��Ա�ȼ� from #t_member_total,#pools where #t_member_total.number = #pools.number

GO
--3����������
--3.1���»���
select * into #t_ponint_total from 
(
 select * from t_point1 
 union 
 select * from t_point2  
 union 
 select * from t_point3  
) as tmp

alter table  #t_ponint_total  add  memberId int; --����һ�б���memberId
go
UPDATE #t_ponint_total 
        SET ��Ա����=T2.VALUE,memberId=T2.ID 
FROM #t_ponint_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE,ID FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.��Ա���� 

--3.2���½���
select * into #t_transaction_total from 
(
 select * from transaction1 
 union 
 select * from transaction2
 union 
 select * from transaction3
) as tmp
alter table  #t_transaction_total  add  memberId  int; --����һ�б���memberId 
go
UPDATE #t_transaction_total 
  SET ��Ա����=T2.VALUE,memberId =T2.ID 
FROM #t_transaction_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE,ID FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.��Ա����
 
--3.3���»�Ա
UPDATE #t_member_total 
        SET ����=T2.VALUE 
FROM #t_member_total(NOLOCK) AS T1 
INNER JOIN (
        SELECT memberno,CodeNo AS VALUE FROM #member_pools(NOLOCK)
) AS T2 ON T2.memberNo=T1.����
GO
--4���浽��Ա�����ֱ����ױ�����ͬ����ҵ�����
INSERT INTO dbo.t_MemberCrm_Test(isCheck,memberNo,nickName,realName,gender,birth,logo,mobile,isValidMobile,email,
isValidEmail,cardType,cardNo,isValidCard,levelID,levelName,mall,mallCode,mallName,
isLockPoint,pointAmount,pointAmountValue,pointReward,pointRedemption,pointExpire,nextExpirePoint,nextExpireTime,country,memberPwd,isAllowMarket,sortNo,createTime,updateTime,valid,deleted,createrId,createrName)
select 1,mt.����,mt.�ֻ�,mt.����,ISNULL(mt.�Ա�,0),'1900-01-01 00:00:00.000',null,mt.�ֻ�,1,mt.����,
  case when mt.���� IS NULL then 1 else 0 end,
1,NULL,0,levels.Id,levels.levelName,mall.id,mall.mallCode,mall.mallName,0,null,mt.��ǰ����,0,0,0,0,'1900-01-01 00:00:00.000','�й�',null,1,
0,getdate(),getdate(),1,0,0,'Import' from  #t_member_total mt
left join saas_MainData.dbo.t_Info_Level levels on mt.��Ա�ȼ�+'��Ա' = levels.levelName 
left join saas_MainData.dbo.t_Mall mall on mall.mallName = mt.�����̳� 
--�����Ա�ȼ���¼
INSERT INTO dbo.t_MemberCrm_LevelRecord_Test(memberId,memberNo,memberName,levelId,levelName,valid_begin,valid_end,
sendTime,recordType,recordTypeName,description,sortNo,createTime,updateTime,valid,deleted,createrID,createrName)
select mp.ID,mp.CodeNo,mp.mobile,levels.Id,levels.levelName,levels.startTime,dateadd(day,levels.validTime*30,levels.startTime),
GETDATE(),1,'����','',1000,GETDATE(),GETDATE(),1,0,0,'Import' from  #member_pools mp 
left join saas_MainData.dbo.t_Info_Level levels on mp.levelName+'��Ա' = levels.levelName  where mp.CodeNo is not null 

--���ӳ�ʼ�˻���
INSERT INTO dbo.t_Crm_Point_Test(codeNo,memberID,memberNo,memberNickName,mobile,pointFrom,pointFromName,
partnerId,partnerCode,partnerName,fromID,fromNo,fromName,fromActionID,transAmount,pointAmount,pointSurplus,balanceAmount,
isRedemptionMath,redemptionLog,isExpireMath,proTime,expiryTime,doublingNumber,eventTag,runLog,shop,mall,
mallCode,mallName,isrefund,refundTime,errorStatus,
errorStatusName,errorStatusMsg,description,sortNo,createTime,updateTime,valid,deleted,createrId,createrName) 
select NEWID(),memberPools.ID,memberPools.CodeNo,memberPools.mobile,memberPools.mobile,403,'�ⲿ�ӿ�',3,'CRM','CRMϵͳ',
0,'','',0,0, member.��ǰ����,case when member.��ǰ���� > 0 then member.��ǰ���� else 0 end,0,0,'',0,GETDATE(),'2022-06-30 23:59:59.00',1,'','',0,mall.id,mall.mallCode,mall.mallName,0,'1900-01-01 00:00:00.000',1,'����','����',
'��ʼ��',1000,GETDATE(),GETDATE(),1,0,0,'Import'  from #t_member_total member
inner join #member_pools memberPools on member.���� = memberPools.CodeNo
left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.�����̳�
 where member.���� = memberPools.CodeNo and memberPools.CodeNo is not null 

--���ӻ���
INSERT INTO dbo.t_Crm_Point_Test(codeNo,memberID,memberNo,memberNickName,mobile,pointFrom,pointFromName,partnerId,partnerCode,partnerName,
fromID,fromNo,fromName,fromActionID,transAmount,pointAmount,pointSurplus,balanceAmount,
isRedemptionMath,redemptionLog,isExpireMath,proTime,expiryTime,doublingNumber,eventTag,runLog,shop,mall,
mallCode,mallName,isrefund,refundTime,errorStatus,
errorStatusName,errorStatusMsg,sortNo,createTime,updateTime,valid,deleted,createrId,createrName) 
select NEWID(),member.ID,member.CodeNo,member.mobile,member.mobile,403,'�ⲿ�ӿ�',3,'CRM','CRMϵͳ',
0,'','',0,0, point.��������,0,0,
0,'',0,GETDATE(),'2022-06-30 23:59:59.00',1,'','',0,mall.id,mall.mallCode,mall.mallName,0,'1900-01-01 00:00:00.000',1,'����','����',
1000,GETDATE(),GETDATE(),1,0,0,'Import'  from #t_ponint_total point,#member_pools member
left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.mallName
 where point.��Ա���� = member.CodeNo
--���ӽ���
INSERT INTO dbo.t_Crm_Transaction_Test(memberId,memberName,memberCodeNo,mobile,
ticketNo,oriTicketNo,amount,amountReal,currency,paymentType,isPointMath,pointHistoryCodeNo,
pointMessage,partnerId,partnerCode,partnerName,transTime,uploadTime,transDate,isrefund,refundTime,
eventTag,shopId,shopCode,shopName,mallId,mallCode,mallName,errorStatus,errorStatusName,errorStatusMsg,fromId,doublingNumber,description,
sortNo,createTime,updateTime,valid,deleted,createrId,createrName)
 SELECT member.ID,'�ǳ�',member.CodeNo,member.mobile,
 trans.Mallcoo����,trans.Mallcoo����,trans.���ѽ��,trans.���ѽ��, 'CNY',trans.֧����ʽ,1,NEWID(),
 0,3,'CRM','CRMϵͳ',GETDATE(),GETDATE(),CONVERT(varchar(8),GETDATE(),112),0, '1900-01-01 00:00:00.000',
 NEWID(),trans.Shopid,trans.ShopCode,trans.�̻�,mall.id,mall.mallCode,mall.mallName,1,'����','����',0,0,'',
 1000,GETDATE(),GETDATE(),1,0,0,'Import'
 FROM  #t_transaction_total trans,#member_pools member 
 left join saas_MainData.dbo.t_Mall mall on mall.mallName = member.mallName 
 where trans.��Ա���� = member.CodeNo
  
--ɾ����ʱ��
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

