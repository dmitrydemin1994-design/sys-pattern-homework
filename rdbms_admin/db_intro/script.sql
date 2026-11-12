DROP TABLE IF EXISTS salaries_history CASCADE;
DROP TABLE IF EXISTS employee_projects CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS branch_addresses CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS department_types CASCADE;
DROP TABLE IF EXISTS positions CASCADE;

-- 1. Типы подразделений
CREATE TABLE department_types (
    department_type_id  SERIAL          PRIMARY KEY,
    type_name           VARCHAR(50)     NOT NULL UNIQUE
);

-- 2. Должности
CREATE TABLE positions (
    position_id     SERIAL          PRIMARY KEY,
    position_name   VARCHAR(150)    NOT NULL UNIQUE
);

-- 3. Адреса филиалов (full_address вычисляется автоматически)
CREATE TABLE branch_addresses (
    branch_address_id   SERIAL          PRIMARY KEY,
    region              VARCHAR(100)    NOT NULL,
    city                VARCHAR(100)    NOT NULL,
    street              VARCHAR(150)    NOT NULL,
    house               VARCHAR(20)     NOT NULL,
    full_address        TEXT
        GENERATED ALWAYS AS (
            region || ', г. ' || city || ', ул ' || street || ', д. ' || house
        ) STORED
);

COMMENT ON COLUMN branch_addresses.full_address IS 'Полный адрес, вычисляется автоматически';

-- 4. Структурные подразделения
CREATE TABLE departments (
    department_id       SERIAL          PRIMARY KEY,
    department_name     VARCHAR(200)    NOT NULL UNIQUE,
    department_type_id  INTEGER         NOT NULL
        REFERENCES department_types(department_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE INDEX idx_departments_type ON departments(department_type_id);

-- 5. Проекты
CREATE TABLE projects (
    project_id      SERIAL          PRIMARY KEY,
    project_name    VARCHAR(200)    NOT NULL UNIQUE
);

-- 6. Сотрудники
CREATE TABLE employees (
    employee_id         SERIAL          PRIMARY KEY,
    full_name           VARCHAR(150)    NOT NULL,
    salary              NUMERIC(12,2)   NOT NULL CHECK (salary > 0),
    position_id         INTEGER         NOT NULL
        REFERENCES positions(position_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    department_id       INTEGER         NOT NULL
        REFERENCES departments(department_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    branch_address_id   INTEGER         NOT NULL
        REFERENCES branch_addresses(branch_address_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    hire_date           DATE            NOT NULL
);

CREATE INDEX idx_employees_position   ON employees(position_id);
CREATE INDEX idx_employees_department ON employees(department_id);
CREATE INDEX idx_employees_address    ON employees(branch_address_id);

-- 7. Связующая таблица «сотрудники — проекты»
CREATE TABLE employee_projects (
    employee_id     INTEGER     NOT NULL
        REFERENCES employees(employee_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    project_id      INTEGER     NOT NULL
        REFERENCES projects(project_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (employee_id, project_id)
);

CREATE INDEX idx_employee_projects_project ON employee_projects(project_id);
