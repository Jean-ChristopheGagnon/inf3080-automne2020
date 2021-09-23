SET ECHO ON
SPOOL output.txt

--Jean-Christophe Gagnon GAGJ01099503
--Mbadinga Auxence Maury MBAA12089905
--Anaïs Yaïci YAIA20559707

----------------------Creation de tables----------------------
CREATE TABLE Adresse 
(
    idAdresse INTEGER NOT NULL,
    codePostal VARCHAR(6),
    numeroCivique INTEGER,
    rue VARCHAR(30),
    ville VARCHAR(30),
    pays VARCHAR(30),
    PRIMARY KEY (idAdresse)
);

CREATE TABLE Utilisateur
(
    idUtilisateur INTEGER NOT NULL,
    nom VARCHAR(30),
    prenom VARCHAR(30),
    idAdresse INTEGER,
    numTelephone INTEGER,
    motDePasse VARCHAR(50),
    PRIMARY KEY (idUtilisateur),
    FOREIGN KEY (idAdresse) REFERENCES Adresse
);

CREATE TABLE Client
(
    numeroClient INTEGER NOT NULL,
    qualite VARCHAR(50),
    idUtilisateur INTEGER NOT NULL,
    PRIMARY KEY (numeroClient),
    FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur
);

CREATE TABLE Commis
(
    idCommis INTEGER NOT NULL,
    idUtilisateur INTEGER NOT NULL,
    typeCommis VARCHAR(50),
    PRIMARY KEY (idCommis),
    FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur
);

CREATE TABLE Fournisseur
(
    idFournisseur INTEGER NOT NULL,
    idUtilisateur INTEGER NOT NULL,
    typeFournisseur VARCHAR(30),
    PRIMARY KEY (idFournisseur),
    FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur
);

CREATE TABLE Produit
(
    idProduit INTEGER NOT NULL,
    numeroProduit VARCHAR(50) NOT NULL,
    codeZebre VARCHAR(50) NOT NULL,
    stock INTEGER NOT NULL,
    PRIMARY KEY (idProduit)
);

CREATE TABLE Catalogue
(
    numeroReference INTEGER NOT NULL,
    description VARCHAR(255),
    prixVente DECIMAL(19,2) NOT NULL,
    dateEntree DATE NOT NULL,
    seuilMinimum INTEGER NOT NULL,
    idProduit INTEGER NOT NULL,
    PRIMARY KEY (numeroReference),
    FOREIGN KEY (idProduit) REFERENCES Produit
);

CREATE TABLE Commande
(
    numeroCommande INTEGER NOT NULL,
    numeroClient INTEGER NOT NULL,
    dateCommande DATE NOT NULL,
    numeroReference INTEGER NOT NULL,
    PRIMARY KEY (numeroCommande),
    FOREIGN KEY (numeroClient) REFERENCES Client,
    FOREIGN KEY (numeroReference) REFERENCES Catalogue
);

CREATE TABLE Commande_Catalogue
(
    numeroCommande INTEGER NOT NULL,
    numeroReference INTEGER NOT NULL,
    nombreItem INTEGER NOT NULL,
    CONSTRAINT pk_commandeCatalogue PRIMARY KEY(numeroCommande, numeroReference),
    CONSTRAINT fk_numeroCommande FOREIGN KEY(numeroCommande) REFERENCES Commande,
    CONSTRAINT fk_numeroReference FOREIGN KEY(numeroReference) REFERENCES Catalogue
);

CREATE TABLE Livraison
(
    numeroLivraison INTEGER NOT NULL,
    dateLivraison DATE NOT NULL,
    numeroCommande INTEGER NOT NULL,
    numeroClient INTEGER NOT NULL,
    PRIMARY KEY (numeroLivraison),
    FOREIGN KEY (numeroClient) REFERENCES Client,
    FOREIGN KEY (numeroCommande) REFERENCES Commande
);

CREATE TABLE Facture
(
    numeroFacture INTEGER NOT NULL,
    numeroClient INTEGER NOT NULL,
    idAdresse INTEGER NOT NULL,
    numeroCommande INTEGER NOT NULL,
    montantFacture INTEGER NOT NULL,
    numeroLivraison INTEGER NOT NULL,
    dateLimitePaiement DATE,
    PRIMARY KEY (numeroFacture),
    FOREIGN KEY (numeroClient) REFERENCES Client,
    FOREIGN KEY (idAdresse) REFERENCES Adresse,
    FOREIGN KEY (numeroCommande) REFERENCES Commande,
    FOREIGN KEY (numeroLivraison) REFERENCES Livraison
);

CREATE TABLE Paiement
(
    idPaiement INTEGER NOT NULL,
    datePaiement DATE NOT NULL,
    numeroFacture INTEGER NOT NULL,
    montantPaiement INTEGER NOT NULL,
    PRIMARY KEY (idPaiement),
    FOREIGN KEY (numeroFacture) REFERENCES Facture
);

CREATE TABLE paiementCredit
(
    numeroCarte INTEGER NOT NULL,
    typeCarte VARCHAR(20) NOT NULL,
    idPaiement INTEGER NOT NULL,
    PRIMARY KEY (numeroCarte),
    FOREIGN KEY (idPaiement) REFERENCES Paiement
);

CREATE TABLE paiementCheque
(
    numeroCheque INTEGER NOT NULL,
    identifiantBanque INTEGER NOT NULL,
    idPaiement INTEGER NOT NULL,
    PRIMARY KEY (numeroCheque),
    FOREIGN KEY (idPaiement) REFERENCES Paiement
);

CREATE TABLE Produit_Livraison
(
    idProduit INTEGER NOT NULL,
    numeroLivraison INTEGER NOT NULL,
    quantiteLivree INTEGER NOT NULL,
    CONSTRAINT pk_produitLivraison PRIMARY KEY(idProduit, numeroLivraison),
    CONSTRAINT fk_idProduit FOREIGN KEY(idProduit) REFERENCES Produit,
    CONSTRAINT fk2_numeroLivraison FOREIGN KEY(numeroLivraison) REFERENCES Livraison
);

CREATE TABLE Fournisseur_Produit
(
    idFournisseur INTEGER NOT NULL,
    idProduit INTEGER NOT NULL,
    CONSTRAINT pk_fournisseurProduit PRIMARY KEY(idFournisseur, idProduit),
    CONSTRAINT fk2_idProduit FOREIGN KEY(idProduit) REFERENCES Produit,
    CONSTRAINT fk_idFournisseur FOREIGN KEY(idFournisseur) REFERENCES Fournisseur
);

----------------------Ajout des contraintes checks----------------------
ALTER TABLE PAIEMENTCREDIT ADD CONSTRAINT Type_Carte CHECK (typeCarte in ('VISA', 'MASTER CARD', 'AMERICAN EXPRESS') );
ALTER TABLE Commande_Catalogue ADD CONSTRAINT Quantité_Com CHECK (nombreItem>0);


----------------------Creation triggers----------------------
CREATE OR REPLACE TRIGGER livraisonReduitStock
AFTER INSERT ON Produit_Livraison 
REFERENCING
    NEW AS ligneApres
FOR EACH ROW
BEGIN
    UPDATE Produit
    SET stock = stock - :ligneApres.quantiteLivree
    WHERE :ligneApres.idProduit = Produit.idProduit;
END;
/
CREATE OR REPLACE TRIGGER bloquerLivraisonStock
BEFORE INSERT ON Produit_Livraison
REFERENCING
    NEW AS ligneApres
FOR EACH ROW
DECLARE
    laQuantiteEnStock    INTEGER;
BEGIN
    SELECT stock
    INTO laQuantiteEnStock
    FROM Produit
    WHERE idProduit = :ligneApres.idProduit;
    
    IF :ligneApres.quantiteLivree > laQuantiteEnStock THEN
        raise_application_error(-20100, 'stock disponible insuffisant');
    END IF;
END;
/
CREATE OR REPLACE TRIGGER bloquerLivraisonCommande
BEFORE INSERT ON Produit_Livraison
REFERENCING
    NEW AS ligneApres
FOR EACH ROW
DECLARE
    quantiteCommandee    INTEGER;
BEGIN
    SELECT Commande_Catalogue.nombreItem
    INTO quantiteCommandee
    FROM Commande_Catalogue, Livraison, Catalogue
    WHERE Commande_Catalogue.numeroCommande = Livraison.numeroCommande AND
    Livraison.numeroLivraison = :ligneApres.numeroLivraison AND
    :ligneApres.idProduit = Catalogue.idProduit AND
    Catalogue.numeroReference = Commande_Catalogue.numeroReference;
    
    IF quantiteCommandee < :ligneApres.quantiteLivree THEN
        raise_application_error(-20100, 'La quantité livrée est supérieure à la quantité commandée.');
    END IF;
END;
/
CREATE OR REPLACE TRIGGER bloquerPaiement
BEFORE INSERT ON Paiement
REFERENCING
	NEW AS ligneAprès
FOR EACH ROW
DECLARE
    montantAPayer    INTEGER;
BEGIN
  SELECT montantFacture
  INTO montantAPayer
  FROM Facture
  WHERE numeroFacture = :ligneAprès.numeroFacture;
 
  IF :ligneAprès.montantPaiement > montantAPayer THEN
      raise_application_error(-20100, 'Vous dépassez le montant qui reste à payer');
  END IF;
END;
/
--------------------------Creation fonctions----------------------
CREATE OR REPLACE FUNCTION QuantiteDejaLivree(
    nArticle varchar,
    nCommande number
) 
RETURN number
IS
    qDejaLivree number := 0;
BEGIN
    SELECT quantiteLivree
    INTO qDejaLivree
    FROM Produit_Livraison
    INNER JOIN livraison USING (numeroLivraison)
    INNER JOIN produit USING (idProduit)
    WHERE livraison.numeroCommande = nCommande AND
    produit.numeroProduit = nArticle;
    
    RETURN qDejaLivree;
END;
/

CREATE OR REPLACE FUNCTION TotalFacture(
    nFacture NUMBER
)
RETURN NUMBER
IS
    montantTotal NUMBER := 0;
BEGIN
    SELECT SUM(Produit_Livraison.quantiteLivree*Catalogue.prixVente)
    INTO montantTotal
    FROM Facture
    JOIN Produit_Livraison ON Facture.numeroLivraison = Produit_Livraison.numeroLivraison
    JOIN Catalogue ON Produit_Livraison.idProduit = Catalogue.idProduit
    WHERE Facture.numeroFacture = nFacture;
    
    RETURN montantTotal;
END;
/
------------------Creation procedures------------------
CREATE OR REPLACE PROCEDURE ProduireFacture(
    nLivraison NUMBER,
    dateLimite DATE
)
IS
    CURSOR cur_facture_client_adresse IS
        SELECT *
        FROM Facture
        JOIN Client ON Facture.numeroClient = Client.numeroCLient
        JOIN Utilisateur ON Utilisateur.idUtilisateur = Client.idUtilisateur
        JOIN Adresse ON Adresse.idAdresse = Utilisateur.idAdresse
        JOIN Livraison ON Livraison.numeroLivraison = Facture.numeroLivraison
        WHERE Facture.numeroLivraison = nLivraison;
        
    un_resultat cur_facture_client_adresse%ROWTYPE;
    
    nouveauMontantFacture NUMBER := 0;
BEGIN
    SELECT TotalFacture(numeroFacture)
    INTO nouveauMontantFacture
    FROM Facture
    WHERE Facture.numeroLivraison = nLivraison;
      
    UPDATE Facture
    SET dateLimitePaiement = dateLimite,
        montantFacture = nouveauMontantFacture
    WHERE Facture.numeroLivraison = nLivraison;
    
    OPEN cur_facture_client_adresse;
    LOOP
        FETCH cur_facture_client_adresse INTO un_resultat;
        EXIT WHEN cur_facture_client_adresse%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Numero du client: ' || un_resultat.numeroClient); 
        DBMS_OUTPUT.PUT_LINE('Nom du client: ' || un_resultat.nom);
        DBMS_OUTPUT.PUT_LINE('Prenom du client: ' || un_resultat.prenom);
        DBMS_OUTPUT.PUT_LINE('Adresse du client: ' || un_resultat.numeroCivique || ' ' || un_resultat.rue || ' ' || un_resultat.ville || ' ' || un_resultat.pays || ' ' || un_resultat.codePostal); 
        DBMS_OUTPUT.PUT_LINE('Numéro de livraison: ' || nLivraison);
        DBMS_OUTPUT.PUT_LINE('Date de livraison: ' || un_resultat.dateLivraison);
        DBMS_OUTPUT.PUT_LINE('Nom produit | Type | Code zébré | Numéro Commande | Prix | Quantité');
        FOR un_enregistrement IN ( SELECT *
            FROM Produit_Livraison
            JOIN Produit ON Produit_Livraison.idProduit = Produit.idProduit
            JOIN Catalogue ON Produit_Livraison.idProduit = Catalogue.idProduit
            JOIN Livraison ON Produit_Livraison.numeroLivraison = Livraison.numeroLivraison
            WHERE Produit_Livraison.numeroLivraison = nLivraison
            )
        LOOP
            DBMS_OUTPUT.PUT_LINE(un_enregistrement.description || ', ' || un_enregistrement.numeroProduit || ', ' || un_enregistrement.codeZebre || ', ' || un_enregistrement.numeroCommande || ', ' || 
            un_enregistrement.prixVente || '$, ' || un_enregistrement.quantiteLivree);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Total avant taxe : ' || TotalFacture(un_resultat.numeroFacture) || '$');
        DBMS_OUTPUT.PUT_LINE('Taxe : ' || TotalFacture(un_resultat.numeroFacture)*0.15 || '$');
        DBMS_OUTPUT.PUT_LINE('Total après taxe : ' || TotalFacture(un_resultat.numeroFacture)*1.15 || '$');
        
        
    END LOOP;
END;
/


----------------------Insertions des tables----------------------

--table Adresse--
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (01 ,'H3T1J4',466,'De la vie','Montreal','Canada');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (02 ,'FKG1J4',976,'De l uqam','Montreal','Quebec');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (03 ,'J4R6R8',123,'Des Pizzas','Rome','Italie');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (04 ,'L9D7H2',721,'Jean Talon','Montreal','Canada');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (05 ,'A1Q1W2',482,'Courneuve','Paris','France');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (06 ,'J5T4O9',874,'Okala','Libreville','Gabon');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (07 ,'x4v6g8',562,'Castello','Madrid','Espagne');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (08 ,'S7E9R5',741,'La Kalsa','Sicile','Italie');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (09 ,'3B5K8N',476,'Alenakirie','Owendo','Gabon');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (10 ,'M1Z7F4',679,'St-Charles','Marseille','France');
INSERT INTO ADRESSE(idadresse,CODEPOSTAL, NUMEROCIVIQUE, RUE, VILLE, PAYS) VALUES (11 ,'W4G5I3',333,'Sant Antoni','Barcelone','Espagne');

--table Utilisateur--
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (01, 'Gagnon', 'Jean Christophe', 01, 4325786574, 'yoohohoho');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (02, 'Yaïci', 'Anaïs', 02, 148286876854, 'A+');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (03, 'Mbadinga', 'Auxence Maury', 03, 89834278682, 'Miam');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (04, 'Hello', 'Its me', 04, 65479272657, 'blablabla');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (05, 'Bambours', 'Eric', 05, 14785236584, 'Bambou');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (06, 'Biron', 'Jeanne', 06, 14453789653, '12345');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (07, 'Ondo', 'Helene', 07, 45698234761, 'ABCD');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (08, 'Lepré', 'Jaques', 08, 23657894237, 'MercedesBenz4');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (09, 'Sala', 'Yvan', 09, 789654238, 'Zone51');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (10, 'Chi', 'Long', 10, 4896528763, 'gocha16');
INSERT INTO utilisateur(idutilisateur, NOM, PRENOM, IDADRESSE, NUMTELEPHONE, MOTDEPASSE) VALUES (11, 'Dio', 'Brando', 11, 489635756, 'Mudamudamudaa!');

--table Client--
INSERT INTO CLIENT (NUMEROCLIENT, QUALITE, idutilisateur) VALUES (01,'Libre comme libre', 01);
INSERT INTO CLIENT (NUMEROCLIENT, QUALITE, idutilisateur) VALUES (02,'secret', 02);
INSERT INTO CLIENT (NUMEROCLIENT, QUALITE, idutilisateur) VALUES (03,'C est un mystere pour l humanité', 03); 

--table commis-- 
INSERT INTO COMMIS (IDCOMMIS, IDUTILISATEUR, TYPECOMMIS) VALUES (01, 04, 'Ventes');
INSERT INTO COMMIS (IDCOMMIS, IDUTILISATEUR, TYPECOMMIS) VALUES (02, 05, 'Achats');
INSERT INTO COMMIS (IDCOMMIS, IDUTILISATEUR, TYPECOMMIS) VALUES (03, 06, 'Livraison');
INSERT INTO COMMIS (IDCOMMIS, IDUTILISATEUR, TYPECOMMIS) VALUES (04, 07, 'Comptabilite');

--table fournisseur--
INSERT INTO FOURNISSEUR (IDFOURNISSEUR, IDUTILISATEUR, TYPEFOURNISSEUR)VALUES (01, 08, 'Transformateur');
INSERT INTO FOURNISSEUR (IDFOURNISSEUR, IDUTILISATEUR, TYPEFOURNISSEUR)VALUES (02, 09, 'Importateur');
INSERT INTO FOURNISSEUR (IDFOURNISSEUR, IDUTILISATEUR, TYPEFOURNISSEUR)VALUES (03, 10, 'Livreur');

--table produit--
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (01, 'P0001', 'Z0001',100);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (02, 'P0002', 'Z0002',50);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (03, 'P0003', 'Z0003',300);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (04, 'P0004', 'Z0004',25);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (05, 'P0005', 'Z0005',80);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (06, 'P0006', 'Z0006',75);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (07, 'P0007', 'Z0007',89);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (08, 'P0008', 'Z0008',215);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (09, 'P0009', 'Z0009',178);
INSERT INTO PRODUIT (IDPRODUIT, NUMEROPRODUIT, CODEZEBRE, STOCK) VALUES (10, 'P0010', 'Z0010',20);

--table catalogue--
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(01,'Pc Asus Utra haute vitesse', 200, to_date('2020-01-05', 'YYYY-MM-DD'), 30, 01);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(02,'Processeur Quantique', 500, to_date('2017-11-12', 'YYYY-MM-DD'), 15, 02);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(03,'Puce AMD', 20, to_date('2018-04-15', 'YYYY-MM-DD'), 60, 03);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(04,'Clavier sans fil', 50, to_date('2015-05-08', 'YYYY-MM-DD'), 100, 04);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(05,'Imprimante Hp+', 75, to_date('2012-12-23', 'YYYY-MM-DD'), 150, 05);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(06,'Google Pro', 120, to_date('2001-05-07', 'YYYY-MM-DD'), 50, 06);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(07,'Ram 90Gb', 94, to_date('2019-01-19', 'YYYY-MM-DD'), 80, 07);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(08,'Souris sans fil', 30, to_date('2020-02-28', 'YYYY-MM-DD'), 140, 08);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(09,'Moniteur Pc', 45, to_date('2020-07-16', 'YYYY-MM-DD'), 10, 09);
INSERT INTO CATALOGUE (NUMEROREFERENCE, DESCRIPTION, PRIXVENTE, DATEENTREE, SEUILMINIMUM, IDPRODUIT)VALUES(10,'Ecran Samsung Q+', 150, to_date('2020-09-03', 'YYYY-MM-DD'), 100, 10);

--table commande--
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE ,NUMEROREFERENCE)VALUES(01, 01, to_date('2020-10-01', 'YYYY-MM-DD'),01);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(02, 02, to_date('2020-10-02', 'YYYY-MM-DD'),02);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(03, 03, to_date('2020-10-03', 'YYYY-MM-DD'),03);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(04, 01, to_date('2020-10-04', 'YYYY-MM-DD'),04);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(05, 02, to_date('2020-10-05', 'YYYY-MM-DD'),05);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(06, 03, to_date('2020-10-06', 'YYYY-MM-DD'),06);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(07, 01, to_date('2020-10-07', 'YYYY-MM-DD'),07);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(08, 02, to_date('2020-10-08', 'YYYY-MM-DD'),08);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(09, 03, to_date('2020-10-09', 'YYYY-MM-DD'),09);
INSERT INTO COMMANDE (NUMEROCOMMANDE, NUMEROCLIENT, DATECOMMANDE, NUMEROREFERENCE)VALUES(10, 01, to_date('2020-10-10', 'YYYY-MM-DD'),10);

--table Commande_Catalogue--
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(01, 01, 01);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(01, 02, 02);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(02, 03, 03);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(02, 04, 04);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(03, 05, 05);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(03, 06, 06);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(04, 07, 07);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(04, 08, 08);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(05, 09, 09);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(05, 10, 10);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(06, 01, 11);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(06, 10, 12);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(07, 02, 13);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(07, 09, 14);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(08, 03, 15);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(08, 08, 400);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(09, 04, 17);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(09, 07, 18);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(10, 02, 19);
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(10, 06, 20);

--table Fournisseur_Produit --
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (01,07); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (02,06); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (03,01); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (02,05); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (03,04); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (01,02); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (01,03); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (01,09); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (03,08); 
INSERT INTO Fournisseur_Produit (idFournisseur,idProduit) VALUES (02,10); 

--table livraison
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (01,to_date('2020-11-01', 'YYYY-MM-DD'), 01,01); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (02,to_date('2020-11-02', 'YYYY-MM-DD'), 02,02); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (03,to_date('2020-11-03', 'YYYY-MM-DD'), 03,03); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (04,to_date('2020-11-04', 'YYYY-MM-DD'), 04,01); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (05,to_date('2020-11-05', 'YYYY-MM-DD'), 05,02);  
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (06,to_date('2020-11-06', 'YYYY-MM-DD'), 06,03); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (07,to_date('2020-11-07', 'YYYY-MM-DD'), 07,01);
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (08,to_date('2020-11-08', 'YYYY-MM-DD'), 08,02); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (09,to_date('2020-11-09', 'YYYY-MM-DD'), 09,03); 
INSERT INTO Livraison (numerolivraison,datelivraison,numerocommande,numeroclient) VALUES (10,to_date('2020-11-10', 'YYYY-MM-DD'), 10,01); 

--Produit_Livraison 
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (01, 01, 01); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (06, 03, 06); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (05, 03, 05); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (08, 04, 08); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (10, 05, 10); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (01, 06, 11); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (09, 07, 14); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (08, 08, 01); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (04, 09, 17); --marche
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (02, 10, 19); --marche

--table Facture --
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (101,01,01,01,10000,01,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (102,01,01,04,10000,04,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (103,01,01,07,10000,07,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (104,01,01,010,10000,10,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (105,02,02,02,10000,02,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (106,02,02,08,10000,08,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (107,02,02,05,10000,05,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (108,03,03,03,10000,03,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (109,03,03,06,10000,06,null);
INSERT INTO Facture(numeroFacture,numeroClient,idAdresse,numeroCommande,montantFacture,numeroLivraison,dateLimitePaiement) VALUES (110,03,03,09,10000,09,null);

--table Paiement
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (01, to_date('2020-11-11', 'YYYY-MM-DD'), 101, 1000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (02, to_date('2020-11-12', 'YYYY-MM-DD'), 102, 2000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (03, to_date('2020-11-13', 'YYYY-MM-DD'), 103, 3000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (04, to_date('2020-11-14', 'YYYY-MM-DD'), 104, 4000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (05, to_date('2020-11-15', 'YYYY-MM-DD'), 105, 5000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (06, to_date('2020-11-16', 'YYYY-MM-DD'), 106, 6000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (07, to_date('2020-11-17', 'YYYY-MM-DD'), 107, 7000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (08, to_date('2020-11-18', 'YYYY-MM-DD'), 108, 8000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (09, to_date('2020-11-19', 'YYYY-MM-DD'), 109, 9000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (10, to_date('2020-11-20', 'YYYY-MM-DD'), 110, 10000);
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (11, to_date('2020-11-20', 'YYYY-MM-DD'), 101, 20);

--Paiement_Cheque
INSERT INTO paiementCheque (numeroCheque,identifiantBanque,idPaiement) VALUES (6477,1107,06); 
INSERT INTO paiementCheque (numeroCheque,identifiantBanque,idPaiement) VALUES (3965,1115,07); 
INSERT INTO paiementCheque (numeroCheque,identifiantBanque,idPaiement) VALUES (6255,1104,08); 
INSERT INTO paiementCheque (numeroCheque,identifiantBanque,idPaiement) VALUES (6798,1130,09); 
INSERT INTO paiementCheque (numeroCheque,identifiantBanque,idPaiement) VALUES (6588,1198,10); 

--Paiement_Credit
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (01,'VISA',01);
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (02,'VISA',02);
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (03,'MASTER CARD',02);
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (04,'AMERICAN EXPRESS',03);
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (05,'MASTER CARD',04);
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (06,'AMERICAN EXPRESS',05);


------------------Tests------------------

/*Checks*/
--Paiementcredit
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (07,'AMERICANEXPRESS',05);
--Paiementcredit
INSERT INTO paiementcredit (numerocarte, TYPECARTE, IDPAIEMENT) VALUES (08,'CANADIAN TIRE',05); 
--Commande_Catalog
INSERT INTO COMMANDE_CATALOGUE (NUMEROCOMMANDE, NUMEROREFERENCE, NOMBREITEM)VALUES(10, 02, 0);

/*Triggers*/
---livraisonReduitStock
SELECT STOCK
FROM produit                                                                     
WHERE idproduit=3;                                                                           
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (03, 02, 2); 
SELECT STOCK
FROM produit                                                                     
WHERE idproduit=03;                                                                            

--bloquerLivraisonStock
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (8, 8, 300); 
--bloquerLivraisonCommande
INSERT INTO PRODUIT_LIVRAISON (idproduit, NUMEROLIVRAISON, QUANTITELIVREE) VALUES (06, 10, 22); 
--bloquerPaiement
INSERT INTO Paiement (idPaiement, datePaiement, numeroFacture, montantPaiement) VALUES (12, to_date('2020-11-21', 'YYYY-MM-DD'), 110, 20000); 

/*Fonctions*/
SELECT QuantiteDejaLivree('P0002',10) qDejaLivree FROM DUAL;
SELECT TotalFacture(110) montantTotal FROM DUAL;
SELECT TotalFacture(108) montantTotal FROM DUAL;

/*Procedure*/
EXECUTE ProduireFacture(5,to_date('2020-12-13', 'YYYY-MM-DD'));
EXECUTE ProduireFacture(10,to_date('2020-12-13', 'YYYY-MM-DD'));
EXECUTE ProduireFacture(3,to_date('2020-12-13', 'YYYY-MM-DD'));


