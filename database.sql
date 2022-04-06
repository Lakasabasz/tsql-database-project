use master;
drop database if exists EwidencjaFaktur;
create database EwidencjaFaktur;
use EwidencjaFaktur;
create table Pracownicy(
	[Nr pracownika] int identity(1,1) primary key,
	Imie nvarchar(32) not null,
	Nazwisko nvarchar(32) not null,
	DataZatrudnienia datetime default current_timestamp,
	Login nvarchar(32) not null,
	Password binary(64) not null);
create table Klienci(
	[ID klienta] int identity(1, 1) primary key,
	Imie nvarchar(32) not null,
	Nazwisko nvarchar(32) not null,
	Firma nvarchar(64) not null,
	Adres nvarchar(256) not null,
	[Nr telefonu] varchar(11) not null,
	Email nvarchar(256) not null,
	Nip varchar(11) not null)
create table Produkty(
	Nazwa nvarchar(256) primary key,
	[Cena ewidencyjna] money not null,
	[Cena minimalna] money default 0,
	[Stawka podatku] decimal(3, 3) not null,
	[Stan magazynu] int not null,
	[Stan minimalny] int default 0)
create table Faktury(
	[Nr faktury] int identity(1, 1) primary key,
	[Data wystawienia] datetime default current_timestamp,
	[Forma dostarczenia] nvarchar(8) not null,
	[ID klienta] int not null,
	[Nr pracownika] int not null,
	constraint FK_Faktury_Klienci foreign key([ID klienta]) references Klienci([ID klienta]),
	constraint FK_Faktury_Pracownicy foreign key([Nr pracownika]) references Pracownicy([Nr pracownika]))
create table PozycjeZamówienia(
	[ID pozycji] int identity(1, 1) primary key,
	[Data zamówienia] datetime default current_timestamp,
	[Data dostarczenia] datetime not null,
	[Cena jednostkowa] money not null,
	Ilość int not null,
	Rabat decimal(3, 3) not null,
	[Stawka podatku] decimal(3, 3) not null,
	[ID klienta] int not null,
	[Nr faktury] int null,
	[Nazwa produktu] nvarchar(256) not null,
	constraint FK_PZ_Klienci foreign key([ID klienta]) references Klienci([ID klienta]),
	constraint FK_PZ_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]),
	constraint FK_PZ_Produkty foreign key([Nazwa produktu]) references Produkty([Nazwa]))
create table Płatności(
	[ID płatności] int identity(1, 1) primary key,
	[Termin płatności] datetime not null,
	[Data dokonania wpłaty] datetime null,
	[Nr faktury] int not null,
	constraint FK_Płatności_Faktury foreign key([Nr faktury]) references Faktury([Nr faktury]))

