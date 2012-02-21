soge-ruby
=========

Acces aux comptes particuliers de la [Societe Generale](http://particulier.societegenerale.fr).

Avertissement
-------------

Ce programme est a un stage très précoce de développement.

Fonctionnalités
---------------

L'API permet de lister les comptes et acceder aux operations.

Pour l'instant le programme test.rb affiche simplement la liste des comptes ainsi que leur solde et 
leurs balance quotidienne respectifs.

Dependances
-----------

  * [Ruby](http://www.ruby-lang.org/fr/) ! 1.8 va bien.
  * [Mechanize](http://mechanize.rubyforge.org/)
  * Mechanize requiert [Nokogiri](http://nokogiri.org/) qui a les dépendances suivantes:
    - libxml2
    - libxml2-dev
    - libxslt
    - libxslt-dev
  * [Hpricot](http://hpricot.com)
  * Les outils en ligne de commande `convert` et `compare` de [ImageMagick](http://www.imagemagick.org/script/command-line-tools.php)
  * [yaml], [iconv], [csv], [digest] de la librairie standard de ruby.

Installation
------------
  
  1. Clonez-moi!

        git clone git://github.com/quentin/soge-ruby.git

  2. Installez les dépendances pour Nokogiri (a adapter selon votre OS)

        apt-get install libxml2 libxml2-dev libxslt libxslt-dev

  3. Installez Mechanize et Hpricot
    
        gem install mechanize hpricot

Usage
-----

  * Editez `.sogeconf` et modifiez la valeur des constantes `CODECLI` et `PASS` pour refléter
    les valeurs que vous entrez habituellement pour accéder a vos comptes (code client et 
    mot de passe composé sur le clavier visuel du site).

  * lancez le programme

        ruby test.rb

