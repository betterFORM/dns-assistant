# DNS Scripts

- read-bindconf.pl - reads and parses existing BIND9 config and zonefiles, and returns the data as XML, accordings to the spec in data-samples/data.xml
- write-zone.pl - writes correct BIND9 config and zonefile for a DNS zone from data passed as XML on STDIN

These scripts form the main Import/Export functionality between an existing 
BIND9 config and the forms based web GUI.

"read-bindconf" reads the relevant BIND9 config from files and returns an XML 
to be stored in eXist-DB.  From this point, primary DNS zone data is XML and 
may be modified through the forms GUI.  Any changes need to be written back 
to config and zonefiles.

For testing or staged rollout, it may be preferable to pull in selected zones 
instead of everything at once.  Both will be easily possible.

The primary data will be held in XML, but for production use, it needs to be 
written out in correct BIND9 format.  This is done by "write-zone", followed 
by some postprocessing (validation, version management, nameserver reload).

## Data Format

The reference data format is specified in data-samples/data.xml


