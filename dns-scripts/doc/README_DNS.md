# DNS Background Info: Zone Management

In the following examples I will use ISC BIND 9.x syntax, as BIND is the 
most popular DNS server software used on the Internet.  Other Nameserver 
implementations (dnsd, djbdns etc) may use a different syntax, but the 
concepts are the same.

I will use the domain "albocha.de" in all examples.  Think "example.com".

I will refer to $CUSTOMER at times.  This is a real customer that we are 
are targeting with this application.

## Motivation

DNS administration in general and BIND9 zonefile syntax in particular can be 
confusing for people not familiar with this task.  Even experienced DNS admins 
will make mistakes, and then wonder and debug why it is not working as 
expected.

In 16+ years of DNS administration for $CUSTOMER, I made (and fixed) lots of 
mistakes myself, and explained, helped, debugged and fixed many more mistakes 
made by $CUSTOMER.  More than 90% of all mistakes were not logical errors, 
but syntax errors in zonefiles.

It is obvious that a form-based GUI for the logical part, together with a 
backend that creates syntactically correct zonefiles, would be extremely 
helpful for administrators.

$CUSTOMER also considers letting their own customers edit their zonefiles 
themselves (less work for $CUSTOMER admins).  In this case, a form GUI is 
absolutely mandatory - otherwise it will be MORE work for $CUSTOMER admins to 
debug and fix errors made by their customers.

## Domains and Authoritative Nameservers

When a new Internet domain such as "albocha.de" is registered, the top-level 
domain registrar (DENIC for .de domains) requires that an authoritative 
DNS server is specified [actually at least two, we'll get to that later].

This DNS server is "authoritative" because it holds the primary DNS data 
for that domain (e.g. that "www.albocha.de" points to IP address 
212.204.63.101).  Once the domain is properly registered, any client in the 
world that wishes to contact www.albocha.de will end up asking the 
authoritative nameservers for the IP address [let's ignore caching here].

The primary DNS data for a domain is called a "DNS zone".  An authoritative 
nameserver usually serves multiple DNS zones: a company that runs its own 
DNS server tends to have a handful of zones, $CUSTOMER has approx. 500, and 
big nameservers may serve many thousands of DNS zones.

In any case, each DNS zone must appear in the nameserver configuration.  To 
add the "albocha.de" zone into a BIND9 nameserver, the following config 
fragment needs to be added to the config files of the authoritative nameserver:

 zone "albocha.de" {
     type master;
     file "master/db.albocha.de";
 };

This tells the nameserver that it should serve DNS data for domain 
"albocha.de" and that it is the authoritative Nameserver for this domain 
("type master").  The actual data records are defined in a file 
"db.albocha.de" located in the "master/" subdir below the nameserver config 
directory.

This config fragment needs to be loaded into the BIND9 configuration so that 
the nameserver software knows it should answers queries for the albocha.de 
domain.  I call this "administrative metadata", it is ABOUT a DNS zone (as 
opposed to what's "inside" a DNS zone - the data records).  It must be added 
to the server configuration which requires server admin privileges.

In contrast, all DNS records for the domain are kept in a data file commonly 
called a "zone file".  This is the "db.albocha.de" file referenced above. 
Zone files have a syntax that is completely different from BIND9 config 
files.  Zone file data structure is defined in 
[RFC 1035](https://tools.ietf.org/html/rfc1035).  Customers may be allowed to 
modify the DNS records of their zones (the zonefile contents), but they are 
not allowed to modify the administrative metadata shown above.

To summarize: when dealing with DNS zones, there are DNS zone contents 
(entries in the zonefile), and there is administrative metadata about the 
zone (nameserver config fragments).  Most operations will deal with zonefile 
contents, but our data structure will represent the administrative metadata as 
well.

## Zonefiles

This is the slightly edited version of the "db.albocha.de" zonefile:

 $TTL 86400
 @ IN  SOA ediscom.de. zonemaster.ediscom.de. ( 2015010800 28800 7200 604800 86400
)
   IN  NS  ns1.ediscom.de.
   IN  NS  ns4.variomedia.de.
 
   ;IN  MX 10   webmail.ediscom.de.
   ;IN  MX 100  mail2.ediscom.de.
 
 www                             IN  A     212.204.63.101
 ;ftp                            IN  A     212.204.63.86
 
 ; $Log: db.albocha.de,v $
 ; Revision 1.2  2015/01/08 20:39:03  syscall
 ; add www
 [truncated]

There are several parts in this zonefile:

- $TTL is a global variable.  It defines the default time-to-live values for 
the following records, unless overridden for some peculiar record.
- "@" is a shortcut for "the domain we're talking about".  In this case, "@" 
is identical to "albocha.de.".  "IN" could be removed, it's the default 
anyway (it means "class INternet", which is the only use of DNS these days).
- every zone starts with an "SOA" record (start of authority).  The SOA record 
applies to "@" (== "albocha.de.").  The meaning of SOA record parameters is 
explained below.  All entries up to "www" also apply to "@" (== "albocha.de.",
the domain itself) because they do not start at the beginning of a line.
- Two nameserver records (NS) are defined for the domain.  To register a 
domain, at least two NS records are mandatory.
- there is no MX record for the domain, they're commented out.  It will not be 
possible to receive Email by modern standards, if a domain has no MX record.
- then there are individual DNS records: an A record for "www" 
(== "www.albocha.de.") and another for "ftp" (commented out).
- finally some Revision Control System logs (CVS in this case), commented out 
and not parsed by the nameserver software.

Apart from lines commented out and the global Variable "$TTL", all lines 
represent "Resource Records" as defined in RFC1035.  Even the somewhat special 
"SOA" record.  This means we have a unified operation of add/modify record 
named "x" type "y" with value(s) "z".

## Common DNS Record Types

The following are the most common DNS record types:

- A: specifies that some DNS name has a certain IPv4 address, usually for a host
- AAAA: same, but value is an IPv6 address
- NS: specifies a nameserver, usually for the whole domain
- MX: a server that accepts email, usually for the whole domain
- CNAME: an alias for a DNS name, eg "web" is really "www"
- TXT: an arbitrary string for various purposes
- SPF: a string related to anti-spam measures
- SRV: service location information, often used in Microsoft Windows networks
- TLSA: representation of a TLS X.509 certificate
- PTR: reverse IP address to DNS name mapping

There are also a handful of record types for DNSSEC. In our special case, 
we don't bother the user with these, because they will be generated and 
inserted automatically.  And there are even more, rarely used record types.

## SOA Records and Default Values

Almost always, the SOA record get created when a domain is registered, and 
never touched again. The SOA record for "albocha.de" encodes the following 
information:

- the nameserver that is the authoritative source of data for this domain 
(ediscom.de.)
- a contact email address (zonemaster.ediscom.de. which is actually 
zonemaster@ediscom.de)
- a serial number that must be increased with every change, commonly encoded 
as YYYYMMDDnn (2015010800 is the first edit on Jan 8 2015)
- timing information for slave nameservers

These values should be editable, but it is rarely needed to edit them. For 
this reason, standard SOA values can be configured via "Default Settings". 
These values are used automatically when a new zone is configured.

The serial number should be automatically set on every zone data modification.

## Reverse Zones

Leaving various special record types aside, most DNS zones provide a 
"name->number" database (eg "www.albocha.de" is "212.204.63.101"). These 
are called "forward zones".

ISPs that provide IP space to their customers (such as $CUSTOMER) also need 
to maintain the reverse "number->name" database ("212.204.63.101" is 
"www.albocha.de"). These type of zones are called "reverse zones".

Reverse DNS data is important for Email, since many modern Mailservers do not 
accept mail from a sender whose reverse DNS does not mirror the forward DNS 
(eg "www.albocha.de" -> "212.204.63.101" -> "www.albocha.de").

Reverse DNS zones contain only PTR records. Here is a simplified example:

 @ IN  SOA ediscom.de. zonemaster.ediscom.de. ( 2014120300 28800 7200 604800 86400 )
   IN  NS  ediscom.de.
   IN  NS  ns4.variomedia.de.

 101     IN  PTR   www.albocha.de.

## Master and Slave Zones

A nameserver that is "master" for a zone has all zone data locally, usually 
in a file (the "zonefile").  In contrast, a nameserver that is "slave" does 
not have this information.  A slave nameserver pulls all zone data from one 
or more specified master nameservers (this is called "zone transfer"), then 
serves DNS answers to the public based on this data.

While most zones at $CUSTOMER are master zones, there are some slave zones, 
for good administrative reasons.

## Revision Control Systems

Zonefiles are just configuration files. They do not require revision control 
systems by themselves, but it is common practice to use them for zonefiles. 
This allows to keep track of changes to the zone, or back out mistakes.

Any revision control system may be used. $CUSTOMER uses CVS, which is fine 
for this purpose.

