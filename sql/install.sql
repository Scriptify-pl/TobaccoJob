INSERT INTO `addon_account` (name, label, shared) VALUES
    ('society_tobacco', 'Tobacco Factory', 1);

INSERT INTO `datastore` (name, label, shared) VALUES
    ('society_tobacco', 'Tobacco Factory', 1);

INSERT INTO `addon_inventory` (name, label, shared) VALUES
    ('society_tobacco', 'Tobacco Factory', 1);

INSERT INTO `jobs` (name, label) VALUES
    ('tobacco', 'Tobacco Factory');

INSERT INTO `job_grades`
    (job_name, grade, name, label, salary, skin_male, skin_female)
VALUES
    ('tobacco', 0, 'recruit', 'Rekrut', 20, '{}', '{}'),
    ('tobacco', 1, 'worker', 'Pracownik', 40, '{}', '{}'),
    ('tobacco', 2, 'experienced', 'Doświadczony pracownik', 60, '{}', '{}'),
    ('tobacco', 3, 'manager', 'Kierownik', 85, '{}', '{}'),
    ('tobacco', 4, 'deputy', 'Zastępca szefa', 85, '{}', '{}'),
    ('tobacco', 5, 'boss', 'Szef zakładu', 100, '{}', '{}');
