# Praesentation

## Agenda

- Olaf: DNS bei e.discom - zusammenfassender Ueberblick
- Olaf: typische Probleme im derzeitigen Workflow
- Olaf: Vorstellung unserer Loesung
- Joern: Kurzvorstellung Betterform, XForms, eXistDB usw
- Joern/Olaf: Demo

## Ueberblick: DNS bei e.discom

- DNS ist zentrale, kritische Infrastruktur
  - "Webseite nicht erreichbar", "Mail konnte nicht zugestellt werden"
- ns1.ediscom.de (primaerer Nameserver GBN)
  - autoritativer Nameserver (ca 400 Domains bei e.discom)
  - caching Resolver (beantwortet Fragen zu fremden Domains)
- ns2.ediscom.de (sekundaerer Nameserver HRO)
  - caching Resolver
- Nameserver sind nicht redundant => Problem bei Hardware Ausfall!

## Zusammenhang von Domain-Registrierung und DNS

- Angabe von mind. 2 Nameservern fuer Registrierung erforderlich
  - Standard: ns1.ediscom.de, ns4.variomedia.de
  - DNS-Zone muss vor Registrierung eingerichtet sein
- Bei DNSSEC zusaetzlich Schluessel zum Signieren der Zone

## Nameserver Konfiguration fuer eine Domain

- Domain ~= Zone
  - "DNS Zone" technisch korrekte Bezeichnung
  - forward zone: welche IP hat www.syscall.de?
  - reverse zone: welcher DNS Name gehoert zu IP 212.204.63.101?
- DNS Eintraege fuer eine Zone werden in einem "Zonefile" gemacht
  - definiertes Format RFC1035 => korrekte Syntax wichtig
  - Zonefile enthaelt alle DNS-Daten einer Zone (NS, MX, A Records usw.)
- Zone muss dem Nameserver bekannt gemacht werden
  - Konfigurationsfragment fuer Zone anlegen (bei e.discom etc/zones)
  - korrekte Syntax sehr wichtig
- 2 Dateien zu editieren: Zonefile und Config Fragment
- Spezial Konfigurationen
  - Slave Nameserver und Hidden Primary
  - Reverse Delegation und Classless Reverse Delegation

## Prozedur bei e.discom

- Zonefile von Vorlage kopieren und anpassen
- Zone in Nameserver Config etc/zones eintragen
- Anpassungen in CVS Versionskontrolle einpflegen
  - Protokollierung aller Aenderungen
  - Zugriff auf alle alten Versionen, zB um Fehler rueckgangig zu machen
  - Schnittstelle zum Nameserver => kein Login auf Nameserver noetig
  - "checkin" auf Admin-Rechner, "checkout" auf Nameserver
- named.reload Script ausfuehren
  - Nameserver holt aktuelle Daten aus CVS
  - prueft Syntax der Zonefiles, ignoriert defekte Zonefiles
  - laufenden Nameserver Dienst neu laden

- multiple Fehlerquellen!
  - ist jedem DNS Admin bei e.discom bereits passiert

## Beispiel einer Zonendatei: db.syscall.de

[Aufbau erklaeren, Grundlage fuer naechste Folie "Typische Fehler"]

## Beispiel von Nameserver Config Fragementen

[Aufbau erklaeren, Grundlage fuer naechste Folie "Typische Fehler"]

- master zone
- slave zone

## Typische Fehler im Zonefile

[Erlaeuterung anhand zuvor gezeigter Beispieldatei]

- Erhoehung der Serial Nummer vergessen
- eine Stelle zuviel in Serial Nummer (Integer Overflow)
- Whitespace am Anfang ist relevant
- "." am Ende ist relevant
- inkorrekte Syntax einzelner Eintraege
- inkorrekte Benutzung von Makros ($GENERATE usw)

- Fehler => Aenderung wird ignoriert

## Typische Fehler in Nameserver Config Fragmenten

[Erlaeuterung anhand zuvor gezeigter Beispieldatei]

- Semikolon am Ende vergessen
- keine "Quotes" wo erforderlich
- inkorrekte Verschachtelung

- Kritischer Fehler => Nameserver stuerzt ab, kein Restart bis Korrektur!

## Typische Fehler bei CVS Benutzung

- "checkin" vergessen
- Editor-Fehlbedienung, hat CVS geklappt oder nicht?
- "update" vergessen, CVS Konflikte, inkorrektes Zonefile wenn nicht geloest

- Fehler => Aenderungen nicht wirksam, evtl. inkorrektes Zonefile

## Loesung: Web-Frontend / Backend

- formularbasiertes Frontend (XForms)
  - logisch strukturierte Eingabemaske
  - Typ- und Wertpruefung der eingegebenen Parameter
  - Browser-unabhaengig, auch mit Mobilgeraeten
- interne Repraesentation: XML-Datenbank (eXistDB)
- Backend: System Scripts inkl. Syntax Check, CVS, named.reload (Perl/Shell)
  - liest und erzeugt syntaktisch korrekte Zone- und Config-Files
  - benutzt Tools der Nameserver Software BIND wo moeglich
- ersetzt den bisherigen Workflow edit/cvs/reload, aus dem Web GUI
- alle typischen Fehler durch definiertes Systemverhalten abfangbar

## Features

- alle ueblichen DNS Record Typen (NS, MX, A, AAAA, CNAME, PTR)
  - sowie seltener benutzte (TXT, SPF, SRV usw)
  - DNSSEC und TLSA/DANE
- Wert- und Typ-Pruefung verhindert Eingabe und Verarbeitung falscher Daten
- koexistiert mit bisherigen manuellen Prozeduren
  - keine harte Umstellung
  - auch bei Ausfall des Web GUI "traditionell" bedienbar

## Ausblick: mandantenfaehig

- Kunden koennten ihr DNS selbst verwalten, statt e.discom Admins zu binden
- alle potenziellen Fehler muessen abgefangen werden
  - sonst Mehr- statt Minder-Aufwand
  - bisher nicht realistisch machbar, mit neuem Tool schon
- Integration mit e.discom LDAP Kundendaten
  - wie Trafficmanager, nach Login Zugriff auf eigene Domains
- einheitliche grafische Gestaltung
  - wie Trafficmanager, per HTML/CSS

## Ausblick: DNSSEC

- DNSSEC: kryptographische Validierung von DNS Daten
- Szenario: Angreifer kann "ns1.ediscom.de" als 192.0.2.1 bekannt machen
  - zB "Cache Poisoning", Nameservers hacked
  - Kunden Domains wie syscall.de koennen umgeleitet werden => Desaster!
- mit DNSSEC zusaetzlich Veroeffentlichung eines Crypto Hash
  - nur der echte ns1.ediscom.de hat die passenden Hash Daten
  - der falsche Nameserver braucht Jahre, um einen passenden Hash zu finden
- besondere Sorgfalt erforderlich
  - ganze Domain nicht erreichbar, wenn falsche Hashes vom verantwortlichen NS

## Ausblick: TLSA/DANE

- erfordert DNSSEC
- TLSA: DNS Record Typ fuer Pruefsumme von X.509 Zertifikat
  - Gueltigkeit eines X.509 Certs kann per DNS geprueft werden
- DANE (DNS-based Authentication of Named Entities)
  - derzeit vor allem fuer Mail Server (TLS verschluesseltes SMTP)
  - wird in absehbarer Zeit von allen ueblichen Browsern unterstuetzt
  - Ende der klassischen CAs absehbar
- Auswirkungen auf e.discom
  - Mail Verschluesselung (SMTP, POP/IMAP)
  - Kunden Web-Server HTTP -> HTTPS
  - VPN Dienste

## Joern: Kurzvorstellung Betterform, XForms, eXistDB usw

## Joern/Olaf: Demo

## Presentation of prototype

Possible flow of presentation of the prototype:

1. start with running eXistdb
1. open up app url in browser
1. say some words about the webapp itself like: is build with state-of-the-art webtechnologies (cross-browser, responsive)
1. explain the UI - defaults, zones, help section
1. show defaults and explain it
1. add a new zone
1. edit a zone
1. store it and trigger generation of zone file
1. show generated zone file (probably we should display it in the browser instead of just opening it on filesystem - might be more convincing)
1. show that file landed in CVS
1. show import of existing files (results should be displayed in UI
1. say something about DNSsec
