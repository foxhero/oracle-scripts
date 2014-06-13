connect scott/tiger;

DROP TABLE PERSON_TAB;
DROP TABLE ADDR_TAB;
DROP TYPE PERSON_O;
DROP TYPE ADDRESS_O;
DROP TYPE FULL_NAME_O;


CREATE TYPE ADDRESS_O AS OBJECT (
   "state" CHAR(20),
   "zip" CHAR(20)
)
/

CREATE TABLE ADDR_TAB OF ADDRESS_O;

CREATE TYPE FULL_NAME_O AS OBJECT (
   "first_name" CHAR(20),
   "last_name" CHAR(20)
)
/

CREATE TYPE PERSON_O AS OBJECT (
   "id" integer,
   "name" FULL_NAME_O,
   "addr" REF ADDRESS_O
)
/


CREATE TABLE PERSON_TAB OF PERSON_O;

QUIT;
