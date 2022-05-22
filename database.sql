use master;
drop database if exists EwidencjaFaktur;
go
create database EwidencjaFaktur;
go
use EwidencjaFaktur;
create table Pracownicy(
	[Nr pracownika] int identity(1,1) primary key,
	Imie nvarchar(32) not null,
	Nazwisko nvarchar(32) not null,
	DataZatrudnienia datetime default current_timestamp,
	Login nvarchar(32) not null,
	Password binary(64) not null,
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
	constraint CK_K_nip check (Nip like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
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
	constraint CH_F_fdost check ([Forma dostarczenia] = 'Kurier' or [Forma dostarczenia] = 'Email' or [Forma dostarczenia] = 'Oddział' or [Forma dostarczenia] = 'Inny'))
create table PozycjeFaktury(
	[ID pozycji] int identity(1, 1) primary key,
	[Data zamówienia] datetime default current_timestamp,
	[Data dostarczenia] datetime null,
	[Cena jednostkowa] money not null,
	Ilość int not null,
	Rabat decimal(3, 3) not null,
	[Stawka podatku] decimal(3, 3) not null,
	[ID klienta] int not null,
	[Nr faktury] int null,
	[Nazwa produktu] nvarchar(256) not null,
	constraint FK_PZ_Klienci foreign key([ID klienta]) references Klienci([ID klienta]),
	constraint FK_PZ_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]),
	constraint FK_PZ_Produkty foreign key([Nazwa produktu]) references Produkty([Nazwa]),
	constraint CH_PZ_ddostarczenia check([Data dostarczenia] <= current_timestamp or [Data dostarczenia] is null),
	constraint CH_PZ_ilość check([Ilość] > 0),
	constraint CK_PZ_rabat check([Rabat] <= 1 and [Rabat] >= 0))
create table Płatności(
	[ID płatności] int identity(1, 1) primary key,
	[Termin płatności] datetime not null,
	[Data dokonania wpłaty] datetime null,
	[Nr faktury] int not null,
	constraint FK_Płatności_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]),
	constraint CH_Pł_ddwpłaty check([Data dokonania wpłaty] < [Termin płatności]))
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
end
go
create trigger TR_PF_after_u
on PozycjeFaktury
after insert
as
begin
	declare @cj money
	declare @rb money
	set @cj = (select [Cena jednostkowa] from inserted)
	set @rb = (select Rabat from inserted)
	if @cj*(1-@rb) < 0
	begin
		RAISERROR('Cannot add new item to list because value of item is lower than 0', 16, 1)
		ROLLBACK
	end
end
