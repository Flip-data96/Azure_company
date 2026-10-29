CREATE SCHEMA IF NOT EXISTS azure_company
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE azure_company;
 
-- ---------------------------------------------------------------------

-- SET FOREIGN_KEY_CHECKS = 0;
-- DROP TABLE IF EXISTS works_on, dependent, dept_locations, project, departament, employee;
-- SET FOREIGN_KEY_CHECKS = 1;
 
-- ---------------------------------------------------------------------
-- TABELAS
-- ---------------------------------------------------------------------
CREATE TABLE employee (
  Fname      VARCHAR(30)   NOT NULL,
  Minit      CHAR(1),
  Lname      VARCHAR(30)   NOT NULL,
  Ssn        CHAR(9)       NOT NULL,
  Bdate      DATE,
  Address    VARCHAR(60),
  Sex        CHAR(1),
  Salary     DECIMAL(10,2),
  Super_ssn  CHAR(9),
  Dno        INT           NOT NULL,
  CONSTRAINT pk_employee          PRIMARY KEY (Ssn),
  CONSTRAINT chk_employee_salary  CHECK (Salary > 2000.0),
  CONSTRAINT chk_employee_sex     CHECK (Sex IN ('M', 'F')),
  CONSTRAINT fk_employee_super    FOREIGN KEY (Super_ssn) REFERENCES employee (Ssn)
    ON DELETE SET NULL ON UPDATE CASCADE
);
 
CREATE TABLE departament (            -- nome mantido (com esse "erro") por causa do .pbix
  Dname             VARCHAR(30)  NOT NULL,
  Dnumber           INT          NOT NULL,
  Mgr_ssn           CHAR(9)      NOT NULL,
  Mgr_start_date    DATE,
  Dept_create_date  DATE,
  CONSTRAINT pk_dept           PRIMARY KEY (Dnumber),
  CONSTRAINT unique_name_dept  UNIQUE (Dname),
  CONSTRAINT chk_date_dept     CHECK (Dept_create_date < Mgr_start_date)
);
 
CREATE TABLE dept_locations (
  Dnumber    INT          NOT NULL,
  Dlocation  VARCHAR(30)  NOT NULL,
  CONSTRAINT pk_dept_locations PRIMARY KEY (Dnumber, Dlocation),
  CONSTRAINT fk_dept_locations FOREIGN KEY (Dnumber) REFERENCES departament (Dnumber)
    ON DELETE CASCADE ON UPDATE CASCADE
);
 
CREATE TABLE project (
  Pname      VARCHAR(30)  NOT NULL,
  Pnumber    INT          NOT NULL,
  Plocation  VARCHAR(30),
  Dnum       INT          NOT NULL,
  CONSTRAINT pk_project      PRIMARY KEY (Pnumber),
  CONSTRAINT unique_project  UNIQUE (Pname),
  CONSTRAINT fk_project      FOREIGN KEY (Dnum) REFERENCES departament (Dnumber)
    ON UPDATE CASCADE
);
 
CREATE TABLE works_on (
  Essn   CHAR(9)       NOT NULL,
  Pno    INT           NOT NULL,
  Hours  DECIMAL(3,1)  NOT NULL,
  CONSTRAINT pk_works_on          PRIMARY KEY (Essn, Pno),
  CONSTRAINT chk_works_on_hours   CHECK (Hours >= 0),
  CONSTRAINT fk_employee_works_on FOREIGN KEY (Essn) REFERENCES employee (Ssn)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_project_works_on  FOREIGN KEY (Pno)  REFERENCES project (Pnumber)
    ON UPDATE CASCADE
);
 
CREATE TABLE dependent (
  Essn            CHAR(9)      NOT NULL,
  Dependent_name  VARCHAR(30)  NOT NULL,
  Sex             CHAR(1),
  Bdate           DATE,
  Relationship    VARCHAR(20),
  CONSTRAINT pk_dependent       PRIMARY KEY (Essn, Dependent_name),
  CONSTRAINT chk_dependent_sex  CHECK (Sex IN ('M', 'F')),
  CONSTRAINT fk_dependent       FOREIGN KEY (Essn) REFERENCES employee (Ssn)
    ON DELETE CASCADE ON UPDATE CASCADE
);
 
-- ---------------------------------------------------------------------
-- DADOS (supervisores antes dos subordinados, por causa de fk_employee_super)
-- ---------------------------------------------------------------------
INSERT INTO employee (Fname, Minit, Lname, Ssn, Bdate, Address, Sex, Salary, Super_ssn, Dno) VALUES
('James',    'E', 'Borg',    '888665555', '1937-11-10', '450-Stone-Houston-TX',   'M', 55000, NULL,        1),
('Franklin', 'T', 'Wong',    '333445555', '1955-12-08', '638-Voss-Houston-TX',    'M', 40000, '888665555', 5),
('Jennifer', 'S', 'Wallace', '987654321', '1941-06-20', '291-Berry-Bellaire-TX',  'F', 43000, '888665555', 4),
('John',     'B', 'Smith',   '123456789', '1965-01-09', '731-Fondren-Houston-TX', 'M', 30000, '333445555', 5),
('Ramesh',   'K', 'Narayan', '666884444', '1962-09-15', '975-Fire-Oak-Humble-TX', 'M', 38000, '333445555', 5),
('Joyce',    'A', 'English', '453453453', '1972-07-31', '5631-Rice-Houston-TX',   'F', 25000, '333445555', 5),
('Alicia',   'J', 'Zelaya',  '999887777', '1968-01-19', '3321-Castle-Spring-TX',  'F', 25000, '987654321', 4),
('Ahmad',    'V', 'Jabbar',  '987987987', '1969-03-29', '980-Dallas-Houston-TX',  'M', 25000, '987654321', 4);
 
INSERT INTO departament (Dname, Dnumber, Mgr_ssn, Mgr_start_date, Dept_create_date) VALUES
('Research',       5, '333445555', '1988-05-22', '1986-05-22'),
('Administration', 4, '987654321', '1995-01-01', '1994-01-01'),
('Headquarters',   1, '888665555', '1981-06-19', '1980-06-19');
 
INSERT INTO dept_locations (Dnumber, Dlocation) VALUES
(1, 'Houston'), (4, 'Stafford'), (5, 'Bellaire'), (5, 'Sugarland'), (5, 'Houston');
 
INSERT INTO project (Pname, Pnumber, Plocation, Dnum) VALUES
('ProductX',        1,  'Bellaire',  5),
('ProductY',        2,  'Sugarland', 5),
('ProductZ',        3,  'Houston',   5),
('Computerization', 10, 'Stafford',  4),
('Reorganization',  20, 'Houston',   1),
('Newbenefits',     30, 'Stafford',  4);
 
INSERT INTO works_on (Essn, Pno, Hours) VALUES
('123456789', 1, 32.5), ('123456789', 2, 7.5),
('666884444', 3, 40.0),
('453453453', 1, 20.0), ('453453453', 2, 20.0),
('333445555', 2, 10.0), ('333445555', 3, 10.0), ('333445555', 10, 10.0), ('333445555', 20, 10.0),
('999887777', 30, 30.0), ('999887777', 10, 10.0),
('987987987', 10, 35.0), ('987987987', 30, 5.0),
('987654321', 30, 20.0), ('987654321', 20, 15.0),
('888665555', 20, 0.0);
 
INSERT INTO dependent (Essn, Dependent_name, Sex, Bdate, Relationship) VALUES
('333445555', 'Alice',     'F', '1986-04-05', 'Daughter'),
('333445555', 'Theodore',  'M', '1983-10-25', 'Son'),
('333445555', 'Joy',       'F', '1958-05-03', 'Spouse'),
('987654321', 'Abner',     'M', '1942-02-28', 'Spouse'),
('123456789', 'Michael',   'M', '1988-01-04', 'Son'),
('123456789', 'Alice',     'F', '1988-12-30', 'Daughter'),
('123456789', 'Elizabeth', 'F', '1967-05-05', 'Spouse');
 
-- ---------------------------------------------------------------------
-- FKs CIRCULARES (employee <-> departament): só podem ser criadas depois
-- da carga, pois cada tabela depende da outra.
-- ---------------------------------------------------------------------
ALTER TABLE employee
  ADD CONSTRAINT fk_employee_dno  FOREIGN KEY (Dno)     REFERENCES departament (Dnumber)
    ON UPDATE CASCADE;
 
ALTER TABLE departament
  ADD CONSTRAINT fk_dept_mgr      FOREIGN KEY (Mgr_ssn) REFERENCES employee (Ssn)
    ON UPDATE CASCADE;
 
-- ---------------------------------------------------------------------
-- CONFERÊNCIA
-- ---------------------------------------------------------------------
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE constraint_schema = 'azure_company'
ORDER BY table_name, constraint_type, constraint_name;
