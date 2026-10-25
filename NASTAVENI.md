# Nastaveni profilu a sdileni zaznamu

## 1. Sdilena slozka

Na bratrove PC vytvorte v OneDrivu slozku `MountBlue-zaznamy`.
V OneDrivu zvolte Sdilet, Konkretni lide a pozvete svuj Microsoft ucet.
Na svem PC pozvanku prijmete. Zaznamy lze otevrit ve webovem OneDrivu
v casti Sdilene. Pro synchronizaci do Pruzkumnika pouzijte Pridat zastupce
do Moje soubory, pokud je tato moznost dostupna.

Pro pristup pouze pres web staci opravneni ke cteni. Pridani zastupce
muze vyzadovat opravneni k upravam. Verejny odkaz neni potreba.

## 2. Jednorazove nastaveni na bratrove PC

1. Soubor `Nastaveni.cmd` umistete vedle aktualniho `PovinePsani.ahk`.
2. Spustte `Nastaveni.cmd`. Zadejte heslo `953`.
3. Zaskrtnete, ze tento ucet a pocitac patri bratrovi.
4. Tlacitkem Vybrat vyberte skutecnou mistni slozku v bratrove OneDrivu.
5. Ulozte nastaveni. Program se znovu spusti bez nastavovaciho okna.

Vyber slozky ani zmena profilu nejsou soucasti bezneho panelu.
Alternativne lze skript spustit s argumentem `--setup`.

Bezny profil ma denni cil 250 znaku, bratruv profil 300 znaku.
Tydenni cil je vzdy 10 * denni cil.
Pri uprave limitu se meni pouze `DEFAULT_DAILY_GOAL` a `BROTHER_DAILY_GOAL`.

Profil je navazany na jedinecne ID instalace, ucet Windows a pocitac.
Ulozen je v `%AppData%\MountBlueEnforcer\device.ini` a aktualizace jej zachovavaji.
Zkopirovani tohoto souboru na jiny ucet nebo pocitac neprenese bratrovsky profil
ani nastaveni sdileni. Novy uzivatel automaticky zacina s beznym profilem.

## 3. Otevreni zaznamu

V nasdilene slozce jsou podslozky `ID-instalace\datum`.
ID je viditelne v oddelenem nastavovacim okne.

- `.txt`: citelny prehled zadani, odevzdanych i rozpracovanych pokusu a oprav.
- `.jsonl`: podrobne udalosti vcetne puvodne napsanych a smazanych znaku.

Zaznamenava se pouze cviceni v aktivnim okne MountBlue, nikoliv psani v jinych
aplikacich nebo v heslovych dialozich. Zaznamy se prubezne ukladaji mistne
do `%AppData%\MountBlueEnforcer\logs`. Puvodni zaznamy z doby pred touto verzi
nelze dodatecne zrekonstruovat.

Program kopiruje zaznamy do vybrane slozky; prenos mezi pocitaci zajistuje OneDrive.
Pri nedostupne slozce zustanou zaznamy ulozene mistne a zkusi se prenest znovu.
Pokud OneDrive zobrazuje chybu nebo neni prihlaseny, je potreba ji vyresit
v samotnem OneDrivu. K otevreni se pouziva vlastni Microsoft ucet prijemce,
zadne prihlasovaci udaje se nevkladaji do skriptu ani do GitHubu.

## 4. Ovlivneni ovladani

Bezny vzhled panelu, Odlozit, potvrzovaci tlacitka i Odemknout PC zustavaji zachovany.
Kliknuti na Odemknout funguje pres celou plochu i okraj tlacitka.
Hlidac pri potvrzovani a odemykani neprepina focus zpet do MountBlue.
Vstup se pri startu neblokuje, dokud MountBlue neni skutecne aktivni.
Pri neuspesnem otevreni se nabidne opakovani a PC zustava ovladatelne.
Pause/Break nadale slouzi pro znovunacteni mimo odlozeni.
