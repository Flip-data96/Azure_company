-- Obs.: com 8 funcionários a diferença de tempo é imperceptível, o ganho aqui é de clareza.
-- =====================================================================
USE azure_company;
 
-- =====================================================================
-- A. INDICADORES DO DASHBOARD (equivalentes às medidas DAX)
-- =====================================================================
 
-- A1. Por departamento: Total Func, Total Folha, Media Sal
--     DAX: Total Func = COUNT(employee[Ssn]) | Total Folha = SUM(employee[Salary])
--          Media Sal = AVERAGE(employee[Salary])
SELECT d.Dname                          AS departamento,
       COUNT(e.Ssn)                     AS total_funcionarios,
       COALESCE(SUM(e.Salary), 0)       AS folha_salarial,
       ROUND(AVG(e.Salary), 2)          AS media_salarial
FROM departament d
LEFT JOIN employee e ON e.Dno = d.Dnumber
GROUP BY d.Dnumber, d.Dname
ORDER BY folha_salarial DESC;
 
-- A2. Totais gerais (cartões do dashboard)
SELECT COUNT(*)                AS total_funcionarios,
       SUM(Salary)             AS folha_salarial,
       ROUND(AVG(Salary), 2)   AS media_salarial
FROM employee;
 
-- A3. Nome completo (≈ coluna calculada "Nome Completo")
SELECT Ssn,
       CONCAT_WS(' ', Fname, CONCAT(Minit, '.'), Lname) AS nome_completo
FROM employee
ORDER BY nome_completo;
 
-- A4. Participação de cada departamento na folha
--     DAX: DIVIDE([Total Folha], CALCULATE([Total Folha], ALL(departament)))
SELECT d.Dname AS departamento,
       SUM(e.Salary) AS folha,
       ROUND(100 * SUM(e.Salary) / SUM(SUM(e.Salary)) OVER (), 1) AS pct_da_folha
FROM departament d
JOIN employee e ON e.Dno = d.Dnumber
GROUP BY d.Dnumber, d.Dname
ORDER BY pct_da_folha DESC;
 
-- =====================================================================
-- B. PERFIL DOS COLABORADORES
-- =====================================================================
 
-- B1. Gênero por departamento
SELECT d.Dname AS departamento,
       SUM(e.Sex = 'F') AS mulheres,
       SUM(e.Sex = 'M') AS homens,
       COUNT(*)         AS total
FROM employee e
JOIN departament d ON d.Dnumber = e.Dno
GROUP BY d.Dnumber, d.Dname;
 
-- B2. Média salarial por gênero comparada à média geral (média geral calculada 1 vez)
WITH geral AS (SELECT AVG(Salary) AS media_geral FROM employee)
SELECT e.Sex,
       COUNT(*)                                   AS qtd,
       ROUND(AVG(e.Salary), 2)                    AS media_salarial,
       ROUND(100 * (AVG(e.Salary) / g.media_geral - 1), 1) AS pct_vs_media_geral
FROM employee e
CROSS JOIN geral g
GROUP BY e.Sex, g.media_geral;
 
-- B3. Idade de cada colaborador
SELECT CONCAT(Fname, ' ', Lname) AS colaborador,
       Bdate,
       TIMESTAMPDIFF(YEAR, Bdate, CURDATE()) AS idade
FROM employee
ORDER BY idade DESC;
 
-- B4. Quem ganha acima da média do próprio departamento
--     (window function não pode ir no WHERE, por isso a tabela derivada)
SELECT colaborador, departamento, Salary, media_depto
FROM (
  SELECT CONCAT(e.Fname, ' ', e.Lname)                  AS colaborador,
         d.Dname                                        AS departamento,
         e.Salary,
         ROUND(AVG(e.Salary) OVER (PARTITION BY e.Dno), 2) AS media_depto
  FROM employee e
  JOIN departament d ON d.Dnumber = e.Dno
) t
WHERE Salary > media_depto
ORDER BY departamento, Salary DESC;
 
-- B5. Ranking salarial por departamento (DENSE_RANK: empatados dividem a posição)
SELECT d.Dname AS departamento,
       CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       e.Salary,
       DENSE_RANK() OVER (PARTITION BY e.Dno ORDER BY e.Salary DESC) AS posicao
FROM employee e
JOIN departament d ON d.Dnumber = e.Dno
ORDER BY d.Dname, posicao, colaborador;
 
-- B6. Maior salário de cada departamento, UMA linha por depto (ROW_NUMBER não repete)
--     Para "top N", troque rn = 1 por rn <= N.
WITH ranking AS (
  SELECT e.Dno, e.Fname, e.Lname, e.Salary,
         ROW_NUMBER() OVER (PARTITION BY e.Dno ORDER BY e.Salary DESC, e.Ssn) AS rn
  FROM employee e
)
SELECT d.Dname AS departamento, r.Fname, r.Lname, r.Salary
FROM ranking r
JOIN departament d ON d.Dnumber = r.Dno
WHERE r.rn = 1;
 
-- =====================================================================
-- C. HIERARQUIA E DEPARTAMENTOS
-- =====================================================================
 
-- C1. Colaborador e supervisor (self join)
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       CONCAT(s.Fname, ' ', s.Lname) AS supervisor
FROM employee e
LEFT JOIN employee s ON s.Ssn = e.Super_ssn
ORDER BY supervisor, colaborador;
 
-- C2. Subordinados diretos por supervisor
SELECT CONCAT(s.Fname, ' ', s.Lname) AS supervisor,
       COUNT(*) AS subordinados
FROM employee e
JOIN employee s ON s.Ssn = e.Super_ssn
GROUP BY s.Ssn, s.Fname, s.Lname
ORDER BY subordinados DESC;
 
-- C3. Organograma completo (WITH RECURSIVE): nível e caminho até o topo
WITH RECURSIVE org AS (
  SELECT Ssn, CONCAT(Fname, ' ', Lname) AS nome, 0 AS nivel,
         CAST(CONCAT(Fname, ' ', Lname) AS CHAR(300)) AS caminho
  FROM employee
  WHERE Super_ssn IS NULL
  UNION ALL
  SELECT e.Ssn, CONCAT(e.Fname, ' ', e.Lname), o.nivel + 1,
         CONCAT(o.caminho, ' > ', e.Fname, ' ', e.Lname)
  FROM employee e
  JOIN org o ON e.Super_ssn = o.Ssn
)
SELECT nivel, nome, caminho
FROM org
ORDER BY caminho;
 
-- C4. Gerente de cada departamento, tempo no cargo e idade do departamento
SELECT d.Dname AS departamento,
       CONCAT(m.Fname, ' ', m.Lname) AS gerente,
       d.Mgr_start_date,
       TIMESTAMPDIFF(YEAR,  d.Mgr_start_date,  CURDATE()) AS anos_no_cargo,
       d.Dept_create_date,
       TIMESTAMPDIFF(YEAR,  d.Dept_create_date, CURDATE()) AS anos_de_existencia,
       TIMESTAMPDIFF(MONTH, d.Dept_create_date, d.Mgr_start_date) AS meses_ate_gerente_assumir
FROM departament d
JOIN employee m ON m.Ssn = d.Mgr_ssn
ORDER BY d.Dname;
 
-- C5. Localizações de cada departamento em uma linha só
SELECT d.Dname AS departamento,
       COUNT(*) AS qtd_locais,
       GROUP_CONCAT(l.Dlocation ORDER BY l.Dlocation SEPARATOR ', ') AS locais
FROM departament d
JOIN dept_locations l ON l.Dnumber = d.Dnumber
GROUP BY d.Dnumber, d.Dname;
 
-- C6. Departamentos presentes em Stafford, com o gerente
SELECT d.Dname AS departamento,
       CONCAT(m.Fname, ' ', m.Lname) AS gerente
FROM departament d
JOIN dept_locations l ON l.Dnumber = d.Dnumber
JOIN employee m       ON m.Ssn = d.Mgr_ssn
WHERE l.Dlocation = 'Stafford';
 
-- =====================================================================
-- D. PROJETOS E HORAS
-- =====================================================================
 
-- D1. Horas totais e pessoas por projeto (≈ "Horas por Projeto")
SELECT p.Pname AS projeto,
       d.Dname AS departamento_responsavel,
       COUNT(w.Essn)              AS pessoas_alocadas,
       COALESCE(SUM(w.Hours), 0)  AS horas_totais
FROM project p
JOIN departament d ON d.Dnumber = p.Dnum
LEFT JOIN works_on w ON w.Pno = p.Pnumber
GROUP BY p.Pnumber, p.Pname, d.Dname
ORDER BY horas_totais DESC, p.Pname;
 
-- D2. Matriz de horas: colaborador x projeto (≈ matriz do dashboard)
--     Usa o número do projeto direto em works_on (sem JOIN com project):
--     1=ProductX 2=ProductY 3=ProductZ 10=Computerization 20=Reorganization 30=Newbenefits
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       SUM(CASE WHEN w.Pno = 1  THEN w.Hours END) AS ProductX,
       SUM(CASE WHEN w.Pno = 2  THEN w.Hours END) AS ProductY,
       SUM(CASE WHEN w.Pno = 3  THEN w.Hours END) AS ProductZ,
       SUM(CASE WHEN w.Pno = 10 THEN w.Hours END) AS Computerization,
       SUM(CASE WHEN w.Pno = 20 THEN w.Hours END) AS Reorganization,
       SUM(CASE WHEN w.Pno = 30 THEN w.Hours END) AS Newbenefits,
       COALESCE(SUM(w.Hours), 0)                  AS total_horas
FROM employee e
LEFT JOIN works_on w ON w.Essn = e.Ssn
GROUP BY e.Ssn, e.Fname, e.Lname
ORDER BY total_horas DESC, colaborador;
 
-- D3. Colaboradores com mais de 40 horas alocadas (possível sobrecarga)
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       SUM(w.Hours) AS horas_alocadas
FROM employee e
JOIN works_on w ON w.Essn = e.Ssn
GROUP BY e.Ssn, e.Fname, e.Lname
HAVING SUM(w.Hours) > 40;
 
-- D4. Colaboradores sem horas lançadas (sem registro ou com 0 hora)
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       d.Dname AS departamento,
       COALESCE(SUM(w.Hours), 0) AS horas
FROM employee e
JOIN departament d ON d.Dnumber = e.Dno
LEFT JOIN works_on w ON w.Essn = e.Ssn
GROUP BY e.Ssn, e.Fname, e.Lname, d.Dname
HAVING COALESCE(SUM(w.Hours), 0) = 0;
 
-- D5. Custo estimado de mão de obra por projeto
--     Premissas: Salary é mensal e o mês tem 160 horas úteis (ajuste à regra real).
SELECT p.Pname AS projeto,
       ROUND(SUM(w.Hours * e.Salary) / 160, 2) AS custo_estimado
FROM works_on w
JOIN employee e ON e.Ssn = w.Essn
JOIN project  p ON p.Pnumber = w.Pno
GROUP BY p.Pnumber, p.Pname
ORDER BY custo_estimado DESC;
 
-- D6. Projetos executados fora das localizações do departamento responsável
--     (NOT EXISTS: seguro com NULL e eficiente)
SELECT p.Pname AS projeto, p.Plocation, d.Dname AS departamento
FROM project p
JOIN departament d ON d.Dnumber = p.Dnum
WHERE NOT EXISTS (
  SELECT 1 FROM dept_locations l
  WHERE l.Dnumber = p.Dnum AND l.Dlocation = p.Plocation
);
 
-- D7. Horas em projetos de OUTRO departamento (alocação entre departamentos)
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       de.Dname AS depto_do_colaborador,
       p.Pname  AS projeto,
       dp.Dname AS depto_do_projeto,
       w.Hours
FROM works_on w
JOIN employee    e  ON e.Ssn = w.Essn
JOIN project     p  ON p.Pnumber = w.Pno
JOIN departament de ON de.Dnumber = e.Dno
JOIN departament dp ON dp.Dnumber = p.Dnum
WHERE e.Dno <> p.Dnum
ORDER BY w.Hours DESC;
 
-- D8. Projetos em Stafford com dados do gerente do departamento responsável
SELECT p.Pnumber, p.Pname, d.Dname, e.Lname AS gerente, e.Address, e.Bdate
FROM project p
JOIN departament d ON d.Dnumber = p.Dnum
JOIN employee e    ON e.Ssn = d.Mgr_ssn
WHERE p.Plocation = 'Stafford';
 
-- =====================================================================
-- E. DEPENDENTES
-- =====================================================================
 
-- E1. Dependentes por relação (≈ gráfico "Dependentes por Relação")
SELECT Relationship AS relacao, COUNT(*) AS quantidade
FROM dependent
GROUP BY Relationship
ORDER BY quantidade DESC, relacao;
 
-- E2. Quantidade de dependentes por funcionário (já com GROUP BY, ao contrário do original)
SELECT e.Ssn, CONCAT(e.Fname, ' ', e.Lname) AS colaborador,
       COUNT(*) AS qtd_dependentes
FROM employee e
JOIN dependent dp ON dp.Essn = e.Ssn
GROUP BY e.Ssn, e.Fname, e.Lname
ORDER BY qtd_dependentes DESC, colaborador;
 
-- E3. Funcionários SEM dependentes (anti-join)
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador
FROM employee e
WHERE NOT EXISTS (SELECT 1 FROM dependent dp WHERE dp.Essn = e.Ssn)
ORDER BY colaborador;
 
-- E4. Dependentes por departamento (inclui departamentos sem nenhum)
SELECT d.Dname AS departamento,
       COUNT(dp.Dependent_name) AS dependentes
FROM departament d
LEFT JOIN employee  e  ON e.Dno = d.Dnumber
LEFT JOIN dependent dp ON dp.Essn = e.Ssn
GROUP BY d.Dnumber, d.Dname;
 
-- =====================================================================
-- F. QUALIDADE DE DADOS (conferir antes de enviar um relatório)
-- =====================================================================
 
-- F1. Totais de controle (devem bater com o dashboard)
SELECT (SELECT COUNT(*)    FROM employee)    AS total_funcionarios,
       (SELECT SUM(Salary) FROM employee)    AS folha_total,
       (SELECT COUNT(*)    FROM departament) AS total_departamentos,
       (SELECT COUNT(*)    FROM project)     AS total_projetos,
       (SELECT SUM(Hours)  FROM works_on)    AS horas_totais;
 
-- F2. Salário nulo ou fora da regra (> 2000)
SELECT Ssn, Fname, Lname, Salary
FROM employee
WHERE Salary IS NULL OR Salary <= 2000;
 
-- F3. Registros de horas zerados ou negativos
SELECT Essn, Pno, Hours
FROM works_on
WHERE Hours <= 0;
 
-- F4. Dependentes órfãos (sem funcionário) — só ocorre se a FK não estiver aplicada
SELECT dp.Essn, dp.Dependent_name
FROM dependent dp
WHERE NOT EXISTS (SELECT 1 FROM employee e WHERE e.Ssn = dp.Essn);
 
-- F5. Departamentos sem funcionários
SELECT d.Dname
FROM departament d
WHERE NOT EXISTS (SELECT 1 FROM employee e WHERE e.Dno = d.Dnumber);
 
-- F6. Gerente que não pertence ao próprio departamento
SELECT d.Dname AS departamento, CONCAT(m.Fname, ' ', m.Lname) AS gerente, m.Dno AS depto_do_gerente
FROM departament d
JOIN employee m ON m.Ssn = d.Mgr_ssn
WHERE m.Dno <> d.Dnumber;
 
-- F7. Subordinado que ganha mais que o supervisor
SELECT CONCAT(e.Fname, ' ', e.Lname) AS colaborador, e.Salary,
       CONCAT(s.Fname, ' ', s.Lname) AS supervisor,  s.Salary AS salario_supervisor
FROM employee e
JOIN employee s ON s.Ssn = e.Super_ssn
WHERE e.Salary > s.Salary;
 
-- =====================================================================
-- G. EXERCÍCIOS DO SCRIPT ORIGINAL (corrigidos)
-- =====================================================================
 
-- G1. Data de nascimento e endereço de John B Smith
--     (use aspas retas '...'; aspas curvas ‘...’ são inválidas em SQL)
SELECT Bdate, Address
FROM employee
WHERE Fname = 'John' AND Minit = 'B' AND Lname = 'Smith';
 
-- G2. Funcionários do departamento Research
--     (a tabela é "departament"; use sempre minúsculas nos nomes das tabelas)
SELECT e.Fname, e.Lname, e.Address
FROM employee e
JOIN departament d ON d.Dnumber = e.Dno
WHERE d.Dname = 'Research';
 
-- G3. Funcionários em departamentos específicos (IN) — vazio com os dados atuais
SELECT Ssn, Fname, Lname, Dno
FROM employee
WHERE Dno IN (3, 6, 9);
 
-- G4. INSS (alíquota fixa de 1,1% é só exercício; o INSS real é progressivo)
SELECT Fname, Lname, Salary, ROUND(Salary * 0.011, 2) AS INSS
FROM employee;
 
-- G5. Aumento de 10% para quem trabalha no ProductX
SELECT e.Fname, e.Lname, ROUND(1.1 * e.Salary, 2) AS increased_sal
FROM employee e
JOIN works_on w ON w.Essn = e.Ssn
JOIN project  p ON p.Pnumber = w.Pno
WHERE p.Pname = 'ProductX';
 
-- G6. Mesmo aumento, só para GERENTES (EXISTS; vazio com os dados atuais)
SELECT e.Fname, e.Lname, ROUND(1.1 * e.Salary, 2) AS increased_sal
FROM employee e
JOIN works_on w ON w.Essn = e.Ssn
JOIN project  p ON p.Pnumber = w.Pno
WHERE p.Pname = 'ProductX'
  AND EXISTS (SELECT 1 FROM departament d WHERE d.Mgr_ssn = e.Ssn);
 
-- =====================================================================
-- H. VIEWS PARA O POWER BI (opcionais; o .pbix atual NÃO depende delas)
-- =====================================================================
CREATE OR REPLACE VIEW vw_resumo_departamento AS
SELECT d.Dnumber,
       d.Dname                      AS departamento,
       COUNT(e.Ssn)                 AS total_funcionarios,
       COALESCE(SUM(e.Salary), 0)   AS folha_salarial,
       ROUND(AVG(e.Salary), 2)      AS media_salarial
FROM departament d
LEFT JOIN employee e ON e.Dno = d.Dnumber
GROUP BY d.Dnumber, d.Dname;
 
CREATE OR REPLACE VIEW vw_horas_projeto AS
SELECT p.Pnumber,
       p.Pname                      AS projeto,
       d.Dname                      AS departamento_responsavel,
       COUNT(w.Essn)                AS pessoas_alocadas,
       COALESCE(SUM(w.Hours), 0)    AS horas_totais
FROM project p
JOIN departament d ON d.Dnumber = p.Dnum
LEFT JOIN works_on w ON w.Pno = p.Pnumber
GROUP BY p.Pnumber, p.Pname, d.Dname;
 
-- =====================================================================
-- I. COMO CONFERIR O USO DE ÍNDICES (EXPLAIN)
--    Veja a coluna "key": deve citar o índice da FK/PK quando a tabela crescer.
--    Em tabelas minúsculas o MySQL pode preferir varrer a tabela inteira.
-- =====================================================================
EXPLAIN SELECT e.Fname, e.Lname FROM employee e WHERE e.Dno = 5;
 
EXPLAIN SELECT p.Pname, SUM(w.Hours)
FROM project p
JOIN works_on w ON w.Pno = p.Pnumber
GROUP BY p.Pnumber, p.Pname;
 
