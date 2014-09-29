USE [master]
GO

/****** Object:  Database [OSCustomizationDB]    Script Date: 9/28/2014 10:31:23 PM ******/
CREATE DATABASE [OSCustomizationDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'OSCustomizationDB', FILENAME = N'R:\Default\OSCustomizationDB.mdf' , SIZE = 3072KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'OSCustomizationDB_log', FILENAME = N'T:\Default\OSCustomizationDB_log.ldf' , SIZE = 1024KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO

ALTER DATABASE [OSCustomizationDB] SET COMPATIBILITY_LEVEL = 110
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [OSCustomizationDB].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE [OSCustomizationDB] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET ARITHABORT OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET AUTO_CLOSE OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET AUTO_CREATE_STATISTICS ON 
GO

ALTER DATABASE [OSCustomizationDB] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [OSCustomizationDB] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE [OSCustomizationDB] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET  DISABLE_BROKER 
GO

ALTER DATABASE [OSCustomizationDB] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET TRUSTWORTHY OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [OSCustomizationDB] SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET RECOVERY FULL 
GO

ALTER DATABASE [OSCustomizationDB] SET  MULTI_USER 
GO

ALTER DATABASE [OSCustomizationDB] SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE [OSCustomizationDB] SET DB_CHAINING OFF 
GO

ALTER DATABASE [OSCustomizationDB] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO

ALTER DATABASE [OSCustomizationDB] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO

ALTER DATABASE [OSCustomizationDB] SET  READ_WRITE 
GO




USE [OSCustomizationDB]
GO

/****** Object:  Table [dbo].[OSCustomizationSettings]    Script Date: 9/28/2014 10:31:06 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OSCustomizationSettings](
	[Profile_ID] [nvarchar](10) NOT NULL,
	[Profile_Netmask] [nvarchar](15) NOT NULL,
	[Profile_GW] [nvarchar](15) NOT NULL,
	[Profile_Datastore] [nvarchar](max) NOT NULL,
	[Profile_ResourcePool] [nvarchar](max) NOT NULL,
	[Profile_DNS] [nvarchar](max) NOT NULL,
	[Profile_CustSpec] [nvarchar](max) NOT NULL,
	[Profile_Template] [nvarchar](max) NOT NULL,
	[Profile_OU] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Table_1] PRIMARY KEY CLUSTERED 
(
	[Profile_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

