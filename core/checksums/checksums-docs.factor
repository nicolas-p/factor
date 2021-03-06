USING: byte-arrays help.markup help.syntax sequences strings ;
IN: checksums

HELP: checksum
{ $class-description "The class of checksum algorithms." } ;

HELP: checksum-stream
{ $values { "stream" "an input stream" } { "checksum" "a checksum specifier" } { "value" byte-array } }
{ $contract "Computes the checksum of all data read from the stream." }
{ $side-effects "stream" } ;

HELP: checksum-bytes
{ $values { "bytes" "a sequence of bytes" } { "checksum" "a checksum specifier" } { "value" byte-array } }
{ $contract "Computes the checksum of all data in a sequence." }
{ $examples
    { $example
        "USING: checksums checksums.crc32 prettyprint ;"
        "B{ 1 10 100 } crc32 checksum-bytes ."
        "B{ 78 179 254 238 }"
    }
} ;

HELP: checksum-lines
{ $values { "lines" "a sequence of sequences of bytes" } { "checksum" "a checksum specifier" } { "value" byte-array } }
{ $contract "Computes the checksum of all data in a sequence." }
{ $examples
    { $example
        "USING: checksums checksums.crc32 prettyprint ;"
"{
    \"Take me out to the ball game\"
    \"Take me out with the crowd\"
} crc32 checksum-lines ."
        "B{ 111 205 9 27 }"
    }
} ;

HELP: checksum-file
{ $values { "path" "a pathname specifier" } { "checksum" "a checksum specifier" } { "value" byte-array } }
{ $contract "Computes the checksum of all data in a file." }
{ $examples
    { $example
        "USING: checksums checksums.crc32 prettyprint ;"
        "\"resource:LICENSE.txt\" crc32 checksum-file ."
        "B{ 100 139 199 92 }"
    }
} ;

ARTICLE: "checksums" "Checksums"
"A " { $emphasis "checksum" } " is a function mapping sequences of bytes to fixed-length strings. While checksums are not one-to-one, a good checksum should have a low probability of collision. Additionally, some checksum algorithms are designed to be hard to reverse, in the sense that finding an input string which hashes to a given checksum string requires a brute-force search."
$nl
"Checksums are instances of a class:"
{ $subsections checksum }
"Operations on checksums:"
{ $subsections
    checksum-bytes
    checksum-stream
    checksum-lines
}
"Checksums should implement at least one of " { $link checksum-bytes } " and " { $link checksum-stream } ". Implementing " { $link checksum-lines } " is optional."
$nl
"Utilities:"
{ $subsections
    checksum-file
}
"Checksum implementations:"
{ $subsections "checksums.crc32" }
{ $vocab-subsection "MD5 checksum" "checksums.md5" }
{ $vocab-subsection "SHA checksums" "checksums.sha" }
{ $vocab-subsection "Adler-32 checksum" "checksums.adler-32" }
{ $vocab-subsection "OpenSSL checksums" "checksums.openssl" }
{ $vocab-subsection "Internet checksum" "checksums.internet" } ;

ABOUT: "checksums"
