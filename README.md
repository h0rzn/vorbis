# Flac+OGG Vorbis tool

*Work In Progress*  

Read out vorbis metadata from compatible flac and ogg files.  
Allows output to be formatted as "raw" text, json and formatted text.

```
--+ Raw Text +--
COMMENT=Visit https://obliqueoccasions.bandcamp.com
ALBUMARTIST=Oblique Occasions
TRACKNUMBER=1
TITLE=operation paperclip
ARTIST=Oblique Occasions
DATE=2024
ALBUM=solipsism

--+ JSON +--
{"COMMENT":"Visit https://obliqueoccasions.bandcamp.com","ALBUMARTIST":"Oblique Occasions","TRACKNUMBER":"1","TITLE":"operation paperclip","ARTIST":"Oblique Occasions","DATE":"2024","ALBUM":"solipsism"}

--+ Pretty (with color) +--
COMMENT: Visit https://obliqueoccasions.bandcamp.com
ALBUMARTIST: Oblique Occasions
TRACKNUMBER: 1
TITLE: operation paperclip
ARTIST: Oblique Occasions
DATE: 2024
ALBUM: solipsism
```
