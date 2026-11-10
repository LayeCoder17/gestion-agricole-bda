-- Schéma de la base « Gestion comptable agricole » (PostgreSQL)
-- Extrait de documents/agri_modeling.md, qui explique chaque choix.

CREATE TABLE produits (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE variete (
    id SERIAL PRIMARY KEY,
    id_produit INT NOT NULL,
    nom_variete VARCHAR(100) NOT NULL,
    description TEXT,
    date_ajout TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_produit) REFERENCES produits(id) ON DELETE CASCADE,
    UNIQUE(id_produit, nom_variete)
);

CREATE TABLE tarif (
    id SERIAL PRIMARY KEY,
    id_variete INT NOT NULL,
    prix_kg DECIMAL(10, 2) NOT NULL CHECK (prix_kg >= 0),
    date_debut DATE NOT NULL,
    date_fin DATE,
    marche VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_variete) REFERENCES variete(id) ON DELETE RESTRICT,
    CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

CREATE TABLE recolte (
    id SERIAL PRIMARY KEY,
    id_variete INT NOT NULL,
    quantite_kg DECIMAL(10, 2) NOT NULL CHECK (quantite_kg > 0),
    date_recolte DATE NOT NULL,
    num_lot VARCHAR(50) UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_variete) REFERENCES variete(id) ON DELETE RESTRICT
);

CREATE TABLE stock (
    id SERIAL PRIMARY KEY,
    id_variete INT NOT NULL UNIQUE,
    quantite_disponible DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (quantite_disponible >= 0),
    derniere_maj TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_variete) REFERENCES variete(id) ON DELETE CASCADE
);

CREATE TABLE vente (
    id SERIAL PRIMARY KEY,
    id_stock INT NOT NULL,
    quantite_kg DECIMAL(10, 2) NOT NULL CHECK (quantite_kg > 0),
    prix_unitaire DECIMAL(10, 2) NOT NULL CHECK (prix_unitaire >= 0),
    montant_total DECIMAL(12, 2) GENERATED ALWAYS AS (quantite_kg * prix_unitaire) STORED,
    date_vente DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_stock) REFERENCES stock(id) ON DELETE RESTRICT
);

CREATE TABLE perte (
    id SERIAL PRIMARY KEY,
    id_stock INT NOT NULL,
    quantite_kg DECIMAL(10, 2) NOT NULL CHECK (quantite_kg > 0),
    raison_perte VARCHAR(200),
    date_perte DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_stock) REFERENCES stock(id) ON DELETE RESTRICT
);

CREATE TABLE rapport_statistique (
    id SERIAL PRIMARY KEY,
    periode VARCHAR(50),
    id_variete INT,
    total_recolte_kg DECIMAL(10, 2),
    total_vente_kg DECIMAL(10, 2),
    total_perte_kg DECIMAL(10, 2),
    ca_periode DECIMAL(12, 2),
    taux_vente_pct DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_variete) REFERENCES variete(id) ON DELETE SET NULL
);
CREATE INDEX idx_recolte_id_variete ON recolte(id_variete);
CREATE INDEX idx_recolte_date ON recolte(date_recolte);
CREATE INDEX idx_vente_id_stock ON vente(id_stock);
CREATE INDEX idx_vente_date ON vente(date_vente);
CREATE INDEX idx_perte_id_stock ON perte(id_stock);
CREATE INDEX idx_tarif_id_variete ON tarif(id_variete);
CREATE INDEX idx_rapport_id_variete ON rapport_statistique(id_variete);
-- ==================== SORTIES : VENTE ET PERTE ====================
-- Une vente et une perte retirent toutes deux une quantité du stock
CREATE OR REPLACE FUNCTION maj_stock_sortie()
RETURNS TRIGGER AS $$
BEGIN
    -- Modification ou suppression : on rend d'abord l'ancienne quantité
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        UPDATE stock
        SET quantite_disponible = quantite_disponible + OLD.quantite_kg,
            derniere_maj = CURRENT_TIMESTAMP
        WHERE id = OLD.id_stock;
    END IF;
    -- Ajout ou modification : on retire la nouvelle quantité
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE stock
        SET quantite_disponible = quantite_disponible - NEW.quantite_kg,
            derniere_maj = CURRENT_TIMESTAMP
        WHERE id = NEW.id_stock;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_vente_stock
AFTER INSERT OR UPDATE OR DELETE ON vente
FOR EACH ROW
EXECUTE FUNCTION maj_stock_sortie();

CREATE TRIGGER tr_perte_stock
AFTER INSERT OR UPDATE OR DELETE ON perte
FOR EACH ROW
EXECUTE FUNCTION maj_stock_sortie();


-- ==================== ENTRÉES : RÉCOLTE ====================
-- Une récolte ajoute au stock de sa variété, et crée ce stock à la première récolte
CREATE OR REPLACE FUNCTION maj_stock_recolte()
RETURNS TRIGGER AS $$
BEGIN
    -- Quantité corrigée sur la même variété : on applique seulement la différence,
    -- pour ne pas faire passer le stock sous zéro entre les deux étapes
    IF TG_OP = 'UPDATE' AND OLD.id_variete = NEW.id_variete THEN
        UPDATE stock
        SET quantite_disponible = quantite_disponible + NEW.quantite_kg - OLD.quantite_kg,
            derniere_maj = CURRENT_TIMESTAMP
        WHERE id_variete = NEW.id_variete;
        RETURN NULL;
    END IF;
    -- Suppression, ou changement de variété : on retire l'ancienne quantité
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        UPDATE stock
        SET quantite_disponible = quantite_disponible - OLD.quantite_kg,
            derniere_maj = CURRENT_TIMESTAMP
        WHERE id_variete = OLD.id_variete;
    END IF;
    -- Ajout, ou changement de variété : on ajoute la nouvelle quantité
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        INSERT INTO stock (id_variete, quantite_disponible, derniere_maj)
        VALUES (NEW.id_variete, NEW.quantite_kg, CURRENT_TIMESTAMP)
        ON CONFLICT (id_variete) DO UPDATE
        SET quantite_disponible = stock.quantite_disponible + EXCLUDED.quantite_disponible,
            derniere_maj = CURRENT_TIMESTAMP;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_recolte_stock
AFTER INSERT OR UPDATE OR DELETE ON recolte
FOR EACH ROW
EXECUTE FUNCTION maj_stock_recolte();
