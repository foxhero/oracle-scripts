Rem
Rem $Header: xmlgen2.sql 29-apr-2001.13:23:03 rbooredd Exp $
Rem
Rem xmlgen2.sql
Rem
Rem  Copyright (c) Oracle Corporation 2001. All Rights Reserved.
Rem
Rem    NAME
Rem      xmlgen2.sql - XML generation using SYS_XMLGEN() and SYS_XMLAGG()
Rem
Rem    DESCRIPTION
Rem      This demo shows how to generate Purchase Order XML document
Rem      from existing relational database using SYS_XMLGEN() and SYS_XMLAGG()
Rem      SQL functions
Rem      
Rem      Object views are defined over relational tables to get data in
Rem      canonical form.
Rem
Rem    NOTES
Rem      SYS_XMLGEN() maps UDT attributes names 
Rem         starting with '@' to xml attributes
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    rbooredd    04/29/01 - Merged rbooredd_xml_demo1
Rem    rbooredd    04/29/01 - 
Rem    rbooredd    04/27/01 - Created
Rem

SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100
SET ECHO ON

connect system/manager
grant connect,resource to xmlgen2 identified by xmlgen2;
connect xmlgen2/xmlgen2;

-- Purchase Order Object View Model

-- PhoneList Varray object type
CREATE TYPE PhoneList_vartyp AS VARRAY(10) OF VARCHAR2(20)
/

-- Address object type
CREATE TYPE Address_typ AS OBJECT (
  Street         VARCHAR2(200),
  City           VARCHAR2(200),
  State          CHAR(2),
  Zip            VARCHAR2(20)
  ) 
/

-- Customer object type
CREATE TYPE Customer_typ AS OBJECT (
  CustNo           NUMBER,
  CustName         VARCHAR2(200),
  Address          Address_typ,
  PhoneList        PhoneList_vartyp
)
/


-- StockItem object type
CREATE TYPE StockItem_typ AS OBJECT (
  "@StockNo"    NUMBER,
  Price      NUMBER,
  TaxRate    NUMBER
)
/

-- LineItems object type
CREATE TYPE LineItem_typ AS OBJECT (
  "@LineItemNo"   NUMBER,
  Item    StockItem_typ,
  Quantity     NUMBER,
  Discount     NUMBER
  ) 
/
-- LineItems Nested table
CREATE TYPE LineItems_ntabtyp AS TABLE OF LineItem_typ 
/

-- Purchase Order object type
CREATE TYPE PO_typ AUTHID CURRENT_USER AS OBJECT (
  "@PONO"              NUMBER,
  Customer             Customer_typ,
  OrderDate            DATE,
  ShipDate             TIMESTAMP,
  LineItems_ntab       LineItems_ntabtyp,
  ShipToAddr           Address_typ
 ) 
/
 
-- Create Purchase Order Relational Model tables

--Customer table
CREATE TABLE Customer_tab(
  CustNo                NUMBER NOT NULL,
  CustName              VARCHAR2(200) ,
  Street                VARCHAR2(200) ,
  City                  VARCHAR2(200) ,
  State                 CHAR(2) ,
  Zip                   VARCHAR2(20) ,
  Phone1                VARCHAR2(20),
  Phone2                VARCHAR2(20),
  Phone3                VARCHAR2(20),
  constraint cust_pk PRIMARY KEY (CustNo)
) 
ORGANIZATION INDEX OVERFLOW;

-- Purchase Order table
CREATE TABLE po_tab (
   PONo        NUMBER, /* purchase order no */  
   Custno      NUMBER constraint po_cust_fk references Customer_tab, 
				/*  Foreign KEY referencing customer */
   OrderDate   DATE, /*  date of order */  
   ShipDate    TIMESTAMP, /* date to be shipped */    
   ToStreet    VARCHAR2(200), /* shipto address */    
   ToCity      VARCHAR2(200),    
   ToState     CHAR(2),    
   ToZip       VARCHAR2(20),
   constraint po_pk PRIMARY KEY(PONo)    
); 

--Stock Table
CREATE TABLE Stock_tab (
  StockNo      NUMBER constraint stock_uk UNIQUE,
  Price        NUMBER,
  TaxRate      NUMBER
);

--Line Items Table
CREATE TABLE LineItems_tab(
  LineItemNo           NUMBER,
  PONo                 NUMBER constraint LI_PO_FK REFERENCES po_tab,
  StockNo              NUMBER ,
  Quantity             NUMBER,
  Discount             NUMBER,
  constraint LI_PK PRIMARY KEY (PONo, LineItemNo)
);

-- create Object Views
--Customer Object View
CREATE OR REPLACE VIEW Customer OF Customer_typ
   WITH OBJECT IDENTIFIER(CustNo)
   AS SELECT c.Custno, C.custname,
             Address_typ(C.Street, C.City, C.State, C.Zip),
             PhoneList_vartyp(Phone1, Phone2, Phone3)
        FROM Customer_tab c;

--Purchase order view
CREATE OR REPLACE VIEW PO OF PO_typ
  WITH OBJECT IDENTIFIER ("@PONO")
   AS SELECT P.PONo,
             Customer_typ(P.Custno,C.CustName,C.Address,C.PhoneList),
             P.OrderDate,
             P.ShipDate,
             CAST( MULTISET(
                    SELECT LineItem_typ( L.LineItemNo,
                                  StockItem_typ(L.StockNo,S.Price,S.TaxRate),
                                            L.Quantity, L.Discount)
                     FROM LineItems_tab L, Stock_tab S
                     WHERE L.PONo = P.PONo and S.StockNo=L.StockNo )
                 AS LineItems_ntabtyp),
         Address_typ(P.ToStreet,P.ToCity, P.ToState, P.ToZip)
        FROM PO_tab P, Customer C
        WHERE P.CustNo=C.custNo;



--------------------
-- Populate data
-------------------
-- Establish Inventory

INSERT INTO Stock_tab VALUES(1004, 6750.00, 2) ;
INSERT INTO Stock_tab VALUES(1011, 4500.23, 2) ;
INSERT INTO Stock_tab VALUES(1534, 2234.00, 2) ;
INSERT INTO Stock_tab VALUES(1535, 3456.23, 2) ;

-- Register Customers

INSERT INTO Customer_tab
  VALUES (1, 'Jean Nance', '2 Avocet Drive',
         'Redwood Shores', 'CA', '95054',
         '415-555-1212', NULL, NULL) ;

INSERT INTO Customer_tab
  VALUES (2, 'John Nike', '323 College Drive',
         'Edison', 'NJ', '08820',
         '609-555-1212', '201-555-1212', NULL) ;

-- Place Orders

INSERT INTO PO_tab
  VALUES (1001, 1, SYSDATE, '10-MAY-1997',
          NULL, NULL, NULL, NULL) ;

INSERT INTO PO_tab
  VALUES (2001, 2, SYSDATE, '20-MAY-1997',
         '55 Madison Ave', 'Madison', 'WI', '53715') ;

-- Detail Line Items

INSERT INTO LineItems_tab VALUES(01, 1001, 1534, 12,  0) ;
INSERT INTO LineItems_tab VALUES(02, 1001, 1535, 10, 10) ;
INSERT INTO LineItems_tab VALUES(01, 2001, 1004,  1,  0) ;
INSERT INTO LineItems_tab VALUES(02, 2001, 1011,  2,  1) ;

-------------------------------------------------------
-- Use SYS_XMLGEN() to generate PO in XML format
-------------------------------------------------------
set long 20000
set pages 100
SELECT SYS_XMLGEN(value(p),
           sys.xmlgenformatType.createFormat('PurchaseOrder')).getClobVal() PO
FROM po p
WHERE p."@PONO"=1001;

-------------------------------------------------------
-- Use SYS_XMLAGG() to aggrigate all Purchase Orders
-- into one XML Document
-------------------------------------------------------
set long 20000
set pages 200
SELECT SYS_XMLAGG(SYS_XMLGEN(value(p),
             sys.xmlgenformatType.createFormat('PurchaseOrder'))).getClobVal() PO
FROM po p;


-- cleanup
connect system/manager
drop user xmlgen2 cascade;
