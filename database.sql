use master;
DECLARE @DatabaseName nvarchar(50)
SET @DatabaseName = N'EwidencjaFaktur'

DECLARE @SQL varchar(max)

SELECT @SQL = COALESCE(@SQL,'') + 'Kill ' + Convert(varchar, SPId) + ';'
FROM MASTER..SysProcesses
WHERE DBId = DB_ID(@DatabaseName) AND SPId <> @@SPId

--SELECT @SQL 
EXEC(@SQL)
drop database if exists EwidencjaFaktur;
go
create database EwidencjaFaktur;
go
use EwidencjaFaktur;
go
create table Pracownicy(
	[Nr pracownika] int identity(1,1) primary key,
	Imie nvarchar(32) not null,
	Nazwisko nvarchar(32) not null,
	DataZatrudnienia datetime default current_timestamp,
	Login nvarchar(32) not null,
	Password binary(128) not null,
	constraint CH_Pra_imie check (Imie not like '%[0-9]%'),
	constraint CH_Pra_nazwisko check (Nazwisko not like '%[0-9]%'),
	constraint CH_Pra_data check (DataZatrudnienia <= current_timestamp))
create table Klienci(
	[ID klienta] int identity(1, 1) primary key,
	Imie nvarchar(32) not null,
	Nazwisko nvarchar(32) not null,
	Firma nvarchar(128) not null,
	Kraj nvarchar(64) not null,
	Miasto nvarchar(128) not null,
	[Kod pocztowy] char(5) not null,
	Ulica nvarchar(128) not null,
	[Numer domu] int not null,
	[Numer mieszkania] int null,
	[Nr telefonu] varchar(11) not null,
	Email nvarchar(256) not null,
	Nip char(11) not null,
	constraint CH_K_imie check (Imie not like '%[0-9]%'),
	constraint CH_K_nazwisko check (Nazwisko not like '%[0-9]%'),
	constraint CH_K_email check (Email like '%_@__%.__%'),
	constraint CK_K_nip check (Nip like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							or Nip like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
	constraint CH_K_kodpocztowy check ([Kod pocztowy] like '[0-9][0-9][0-9][0-9][0-9]'))
create table Produkty(
	Nazwa nvarchar(256) primary key,
	[Cena ewidencyjna] money not null,
	[Cena minimalna] money default 0,
	[Stawka podatku] decimal(3, 3) not null,
	[Stan magazynu] int not null,
	[Stan minimalny] int default 0,
	constraint CH_Pro_cewidencyjna check ([Cena ewidencyjna] > 0),
	constraint CH_Pro_cminimalna check ([Cena minimalna] >= 0 and [Cena minimalna] <= [Cena ewidencyjna]),
	constraint CH_Pro_spodatku check ([Stawka podatku] >= 0 and [Stawka podatku] <= 1),
	constraint CH_Pro_smagazynu check ([Stan magazynu] >= 0),
	constraint CH_Pro_sminimalny check ([Stan minimalny] >= 0))
create table Faktury(
	[Nr faktury] int identity(1, 1) primary key,
	[Data wystawienia] datetime default current_timestamp,
	[Forma dostarczenia] varchar(8) not null,
	[ID klienta] int not null,
	[Nr pracownika] int not null,
	constraint FK_Faktury_Klienci foreign key([ID klienta]) references Klienci([ID klienta]),
	constraint FK_Faktury_Pracownicy foreign key([Nr pracownika]) references Pracownicy([Nr pracownika]),
	constraint CH_F_fdost check ([Forma dostarczenia] = 'Kurier' or [Forma dostarczenia] = 'Email' or [Forma dostarczenia] = 'Oddzia??' or [Forma dostarczenia] = 'Inny'))
create table PozycjeFaktury(
	[ID pozycji] int identity(1, 1) primary key,
	[Data zam??wienia] datetime default current_timestamp,
	[Data dostarczenia] datetime null,
	[Cena jednostkowa] money not null,
	Ilo???? int not null,
	Rabat decimal(3, 3) not null,
	[Stawka podatku] decimal(3, 3) not null,
	[ID klienta] int not null,
	[Nr faktury] int null,
	[Nazwa produktu] nvarchar(256) not null,
	constraint FK_PZ_Klienci foreign key([ID klienta]) references Klienci([ID klienta]),
	constraint FK_PZ_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]),
	constraint FK_PZ_Produkty foreign key([Nazwa produktu]) references Produkty([Nazwa]),
	constraint CH_PZ_ddostarczenia check([Data dostarczenia] <= current_timestamp or [Data dostarczenia] is null),
	constraint CH_PZ_ilo???? check([Ilo????] > 0),
	constraint CK_PZ_rabat check([Rabat] <= 1 and [Rabat] >= 0))
create table P??atno??ci(
	[ID p??atno??ci] int identity(1, 1) primary key,
	[Termin p??atno??ci] datetime not null,
	[Data dokonania wp??aty] datetime null,
	[Nr faktury] int not null,
	constraint FK_P??atno??ci_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]),
	constraint CH_P??_ddwp??aty check([Data dokonania wp??aty] < [Termin p??atno??ci]))
go
drop trigger if exists TR_PF_after_i;
drop trigger if exists TR_PF_after_u;
go
create trigger TR_PF_after_i
on PozycjeFaktury
after insert
as
begin
	declare @cj money
	declare @rb money
	declare @np nvarchar(256)
	if (select count(*) from inserted) = 1
	begin
		set @cj = (select [Cena jednostkowa] from inserted)
		set @rb = (select Rabat from inserted)
		set @np = (select [Nazwa produktu] from inserted)
		if @cj*(1-@rb) < (SELECT [Cena minimalna] FROM Produkty WHERE Produkty.Nazwa = @np)
		begin
			RAISERROR('Cannot add new item to list because value of item is lower than minimal price', 16, 1)
			ROLLBACK
		end
		if @cj != (SELECT [Cena ewidencyjna] FROM Produkty WHERE Produkty.Nazwa = @np)
		begin
			RAISERROR('Cannot add new item to list because unit price is differnt than price assigned to product', 16, 1)
			ROLLBACK
		end
		COMMIT
	end
	declare cur scroll cursor
	for select [Cena jednostkowa], Rabat, [Nazwa produktu] from inserted
	for read only;
	open cur;
	while @@FETCH_STATUS=0
	begin
		fetch next from cur into @cj, @rb, @np
		if @cj*(1-@rb) < (SELECT [Cena minimalna] FROM Produkty WHERE Produkty.Nazwa = @np)
		begin
			RAISERROR('Cannot add new item to list because value of item is lower than minimal price', 16, 1)
			ROLLBACK
		end
		if @cj != (SELECT [Cena ewidencyjna] FROM Produkty WHERE Produkty.Nazwa = @np)
		begin
			RAISERROR('Cannot add new item to list because unit price is differnt than price assigned to product', 16, 1)
			ROLLBACK
		end
	end
	close cur;
	deallocate cur;
end
go
create trigger TR_PF_after_u
on PozycjeFaktury
after insert
as
begin
	declare @cj money
	declare @rb money
	if (select count(*) from inserted) = 1
	begin
		set @cj = (select [Cena jednostkowa] from inserted)
		set @rb = (select Rabat from inserted)
		if @cj*(1-@rb) < 0
		begin
			RAISERROR('Cannot add new item to list because value of item is lower than 0', 16, 1)
			ROLLBACK
		end
		commit
	end
	declare cur scroll cursor
	for select [Cena jednostkowa], Rabat from inserted;
	open cur;
	while @@FETCH_STATUS = 0
	begin
		fetch next from cur into @cj, @rb;
		if @cj*(1-@rb) < 0
		begin
			RAISERROR('Cannot add new item to list because value of item is lower than 0', 16, 1)
			ROLLBACK
		end
	end
	close cur;
	deallocate cur;
end

go

create or alter function ffp_faktura(@nrf int)
returns int
as
begin
	return (select min(case when [Data dokonania wp??aty] is null then 0 else 1 end) from P??atno??ci where [Nr faktury] = @nrf)
end

go

create or alter function f_zestawienie(@start Datetime, @end Datetime)
returns @zestawienie table([Numer pracownika] int, Imie nvarchar(32), Nazwisko nvarchar(32), [Warto???? faktur] money, [Warto???? nieop??aconych faktur] money)
as
begin
	declare @tq table(Nrp int, im nvarchar(32), nz nvarchar(32), fnr int, w money, st int)
	insert into @tq select Pracownicy.[Nr pracownika], Imie, Nazwisko,
							Faktury.[Nr faktury], SUM(Ilo????*[Cena jednostkowa]*(1-Rabat)) as fsm, dbo.ffp_faktura(Faktury.[Nr faktury]) as fstat
					from Pracownicy inner join Faktury on Pracownicy.[Nr pracownika] = Faktury.[Nr pracownika]
									inner join PozycjeFaktury on Faktury.[Nr faktury] = PozycjeFaktury.[Nr faktury]
					where Faktury.[Data wystawienia] between @start and @end
					group by Pracownicy.[Nr pracownika], Imie, Nazwisko, Faktury.[Nr faktury];
	insert into @zestawienie
	select q1.Nrp, q1.im, q1.nz, q1.w as wwf, q2.w as wnop
		from (select Nrp, im, nz, sum(w) as w from @tq group by Nrp, im, nz) as q1
		inner join (select Nrp, sum(w) as w from @tq where st = 0 group by Nrp) as q2 on q1.Nrp=q2.Nrp
	return;
end

go

create or alter view v_missing
as
select Nazwa, [Stan magazynu], [Stan minimalny] from Produkty where [Stan magazynu] <= [Stan minimalny]

go

create or alter function f_faktury_klienta(@idk int)
returns @zestawienie table([Nr faktury] int, [Data wystawienia] datetime, [Imie] nvarchar(32), [Nazwisko] nvarchar(32), Warto???? money, Stan varchar(13))
as
begin
	insert into @zestawienie
	select Faktury.[Nr faktury], [Data wystawienia], Imie, Nazwisko, SUM(Ilo????*[Cena jednostkowa]*(1-Rabat)) as Warto????, case when dbo.ffp_faktura(Faktury.[Nr faktury]) = 1 then 'Op??acona' else 'Nie op??acona' end as Stan
	from Klienci inner join Faktury on Klienci.[ID klienta] = Faktury.[ID klienta]
				inner join PozycjeFaktury on Faktury.[Nr faktury] = PozycjeFaktury.[Nr faktury]
	where Klienci.[ID klienta] = 2
	group by Faktury.[Nr faktury], [Data wystawienia], Imie, Nazwisko
	return;
end

go

create or alter procedure p_podatek(@start datetime, @end datetime)
as
begin
	select ' Produkt: ', [Nazwa produktu], [Stawka podatku], count(*) as Ilo????, SUM([Cena jednostkowa]*Ilo????*(1-Rabat)) as Warto????, SUM([Cena jednostkowa]*Ilo????*(1-Rabat)*[Stawka podatku]) as [Warto???? podatku]
	from Faktury inner join PozycjeFaktury on Faktury.[Nr faktury] = PozycjeFaktury.[Nr faktury]
	where Faktury.[Data wystawienia] between @start and @end
	group by [Nazwa produktu], [Stawka podatku]
	union
	select 'Podsumowanie: ', '' as [Nazwa produktu], 0 as [Stawka podatku], count(*) as Ilo????, SUM([Cena jednostkowa]*Ilo????*(1-Rabat)) as Warto????, SUM([Cena jednostkowa]*Ilo????*(1-Rabat)*[Stawka podatku]) as [Warto???? podatku]
	from Faktury inner join PozycjeFaktury on Faktury.[Nr faktury] = PozycjeFaktury.[Nr faktury]
	where Faktury.[Data wystawienia] between @start and @end
end

go

insert into Pracownicy(Imie, Nazwisko, DataZatrudnienia, Login, Password)
VALUES ('Jan', 'Spataro', '01-01-2020', 'jspataro', PWDENCRYPT('niesamowiciesilnehas??o')),
	('??ukasz', 'Mastalerz', '01-02-2020', 'lmastalerz', PWDENCRYPT('niesamowiciesilnehas??o2'));

insert into Produkty(Nazwa,	[Cena ewidencyjna], [Cena minimalna], [Stawka podatku], [Stan magazynu], [Stan minimalny])
VALUES('Produkt 1', 20, 10, 0.23, 40, 5), ('Produkt 2', 40, 5, 0.23, 20, NULL), ('Produkt 3', 5, 0.25, 0.23, 100, 20);

insert into Klienci(Imie, Nazwisko, Firma, Kraj, Miasto, [Kod pocztowy], Ulica, [Numer domu], [Numer mieszkania], [Nr telefonu], Email, Nip)
VALUES('Bartosz', 'Owczarz', 'BO-dalanie', 'Polska', 'Bielsko-Bia??a', '43300', 'Jask????cza', 24, 5, '123456789', 'admin@hosting.xd', '12345678912'),
	('Nikodem', 'Stasiewicz', 'KodenZajumen', 'Niemcy', 'Obersdorf', '06991', 'Gremlinstrasse', 1, NULL, '47987456321', 'zlomiren@serwer.de', '98745632212'),
	('Tomasz', 'Wawoczny', 'Grucha Sp. Z O.O.', 'Polska', 'Kozy', '43344', 'Bielska', 5, NULL, '555666444', 'tw@grucha.pl', '12345678912');

insert into Faktury([Data wystawienia], [Forma dostarczenia], [Nr pracownika], [ID klienta])
VALUES('04.20.2020', 'Email', 1, 1), ('04.30.2020', 'Email', 1, 2), ('08.10.2020', 'Email', 2, 2), ('01.01.2020', 'Kurier', 2, 3);

alter table PozycjeFaktury disable trigger TR_PF_after_i;

insert into PozycjeFaktury([Data zam??wienia], [Data dostarczenia], [Cena jednostkowa], [Ilo????], [Rabat], [Stawka podatku], [ID klienta], [Nr faktury], [Nazwa produktu])
VALUES('04.20.2020', '04.21.2020', 10, 2, 0.1, 0.23, 1, 1, 'Produkt 1'),
	('04.30.2020', '05.01.2020', 10, 2, 0.05, 0.23, 2, 2, 'Produkt 1'),
	('08.10.2020', '08.11.2020', 50, 2, 0.15, 0.23, 2, 3, 'Produkt 2'),
	('01.01.2020', '01.02.2021', 50, 2, 0.1, 0.23, 3, 4, 'Produkt 2'),
	('01.01.2020', '01.02.2021', 1, 2, 0.1, 0.23, 3, 4, 'Produkt 3');

alter table PozycjeFaktury enable trigger TR_PF_after_i;

insert into P??atno??ci([Termin p??atno??ci], [Data dokonania wp??aty], [Nr faktury])
VALUES('04.27.2020', '04.20.2020', 1),
	('04.30.2020', NULL, 2),
	('08.10.2020', NULL, 3),
	('01.07.2020', '01.04.2020', 4)
go
use EwidencjaFaktur;
go
drop user if exists przedstawiciel;
drop user if exists w??a??ciciel;
drop user if exists obs??uga;
drop user if exists magazyn;
drop user if exists ksi??gowo????;
go
use master;
go
drop user if exists przedstawiciel;
drop user if exists w??a??ciciel;
drop user if exists obs??uga;
drop user if exists magazyn;
drop user if exists ksi??gowo????;
if exists (select * from sys.server_principals where name='przedstawiciel') drop login przedstawiciel;
if exists (select * from sys.server_principals where name='w??a??ciciel') drop login w??a??ciciel;
if exists (select * from sys.server_principals where name='obs??uga') drop login obs??uga;
if exists (select * from sys.server_principals where name='magazyn') drop login magazyn;
if exists (select * from sys.server_principals where name='ksi??gowo????') drop login ksi??gowo????;
go
create login przedstawiciel with password = 'has??o', default_database = EwidencjaFaktur;
create login w??a??ciciel with password = 'has??o', default_database = EwidencjaFaktur;
create login obs??uga with password = 'has??o', default_database = EwidencjaFaktur;
create login magazyn with password = 'has??o', default_database = EwidencjaFaktur;
create login ksi??gowo???? with password = 'has??o', default_database = EwidencjaFaktur;
create user przedstawiciel from login przedstawiciel;
create user w??a??ciciel from login w??a??ciciel;
create user obs??uga from login obs??uga;
create user magazyn from login magazyn;
create user ksi??gowo???? from login ksi??gowo????;
go
grant connect sql to przedstawiciel;
grant connect sql to w??a??ciciel;
grant connect sql to obs??uga;
grant connect sql to magazyn;
grant connect sql to ksi??gowo????;
go
use EwidencjaFaktur;
go
create user przedstawiciel for login przedstawiciel;
create user w??a??ciciel from login w??a??ciciel;
create user obs??uga from login obs??uga;
create user magazyn from login magazyn;
create user ksi??gowo???? from login ksi??gowo????;
go
grant select on dbo.f_faktury_klienta to przedstawiciel;
grant select on Produkty to przedstawiciel;
grant select on Klienci to przedstawiciel;
grant select on Pracownicy([Nr pracownika], [Login], [Password]) to przedstawiciel;
go
grant select, update, insert, delete to w??a??ciciel;
go
grant select, update, insert on Klienci to obs??uga;
grant select, insert on Faktury to obs??uga;
grant update on Faktury([Forma dostarczenia]) to obs??uga;
grant select, update, insert, delete on P??atno??ci to obs??uga;
grant select, insert on PozycjeFaktury to obs??uga;
grant select on Produkty to obs??uga;
grant select on Pracownicy([Nr pracownika], [Login], [Password]) to obs??uga;
go
grant select, update, insert on Produkty to magazyn;
grant select on dbo.v_missing to magazyn;
grant select on Pracownicy([Nr pracownika], [Login], [Password]) to przedstawiciel;
go
grant select, update, insert, delete on Faktury to ksi??gowo????;
grant select, update, insert, delete on P??atno??ci to ksi??gowo????;
grant select, update, insert, delete on PozycjeFaktury to ksi??gowo????;
grant exec on p_podatek to ksi??gowo????;
grant select on Produkty to ksi??gowo????;
grant update on Produkty([Stawka podatku]) to ksi??gowo????;
go
backup database master to disk='C:\DatabaseBackup\master.bak';
backup database EwidencjaFaktur to disk='C:\DatabaseBackup\data.bak';
