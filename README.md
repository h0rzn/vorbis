# Flac+OGG Vorbis tool

*Work In Progress*  

Read vorbis metadata from compatible flac and ogg files.  
Vorbis data can be printed as json, raw text and formatted text.
Metadata fields can be filtered using `-f` flag.

## Usage
```
    -h, --help
            Show usage help and exit.

    -v, --version
            Show version information and exit.

    <file>
            Specify input file. Supports both .ogg and .flac files.

    -o, --output-format <format>
            Specify output format. Supported formats: raw, pretty, json

    -f, --fields <keys>
            Specify fields to display by key. Use a comma separated list for multiple values.
```

## Examples
```bash
vorbis
\\ "Oblique Occasions - solipsism - 01 operation paperclip.flac" 
\\ -o json 
\\ -f artist,title,comment

{"ARTIST":"Oblique Occasions","TITLE":"operation paperclip","COMMENT":"Visit https://obliqueoccasions.bandcamp.com"}
```




vorbis "Oblique Occasions - solipsism - 01 operation paperclip.flac" \ 
        -o json \  
        -f artist,title,comment