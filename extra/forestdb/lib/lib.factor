! Copyright (C) 2014 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors alien.c-types alien.data alien.strings
alien.syntax classes.struct combinators constructors
continuations destructors forestdb.ffi fry generalizations
io.encodings.string io.encodings.utf8 io.pathnames kernel libc
math multiline namespaces sequences ;
IN: forestdb.lib

/*
! Possible bugs in foresdtb:

    ! why is meta set but metalen is 0?
    ! also, there is no meta info in these docs
    delete-test-db-1
    test-db-1 [
        5 set-kv-n
        fdb-commit-normal
        "key1" "key5" [
              .
        ] with-fdb-normal-meta-iterator
    ] with-forestdb-path

    ...
    S{ fdb_doc
        { keylen 4 }
        { metalen 0 }
        { bodylen 4 }
        { size_ondisk 0 }
        { key ALIEN: 12721e3f0 }
        { seqnum 5 }
        { offset 4256 }
        { meta ALIEN: 1272308d0 }
        { body f }
        { deleted f }
    }

! snapshot has doc_count of entire file, not in that snapshot
*/

ERROR: fdb-error error ;

: fdb-check-error ( ret -- )
    dup FDB_RESULT_SUCCESS = [
        drop
    ] [
        fdb-error
    ] if ;

TUPLE: fdb-handle < disposable handle ;
: <fdb-handle> ( handle -- obj )
    fdb-handle new-disposable
        swap >>handle ; inline

M: fdb-handle dispose*
    handle>> fdb_close fdb-check-error ;


TUPLE: fdb-doc < disposable doc ;

M: fdb-doc dispose*
    fdb_doc_free fdb-check-error ;


: fdb-open ( path -- handle )
    [ f void* <ref> ] dip
    absolute-path f
    [ fdb_open fdb-check-error ] 3keep
    2drop void* deref <fdb-handle> ;

: ret>string ( void** len -- string )
    [ void* deref ] [ size_t deref ] bi*
    [ memory>byte-array utf8 decode ] [ drop (free) ] 2bi ;

SYMBOL: fdb-current

: get-handle ( -- handle )
    fdb-current get handle>> ;

: fdb-set-kv ( key value -- )
    [ get-handle ] 2dip
    [ dup length ] bi@ fdb_set_kv fdb-check-error ;

: fdb-set ( doc -- )
    [ get-handle ] dip fdb_set fdb-check-error ;

: fdb-del ( doc -- )
    [ get-handle ] dip fdb_del fdb-check-error ;

: fdb-get-kv ( key -- value/f )
    [ get-handle ] dip
    dup length f void* <ref> 0 size_t <ref>
    [ fdb_get_kv ] 2keep
    rot {
        { FDB_RESULT_SUCCESS [ ret>string ] }
        { FDB_RESULT_KEY_NOT_FOUND [ 2drop f ] }
        [ fdb-error ]
    } case ;

: fdb-del-kv ( key -- )
    [ get-handle ] dip dup length fdb_del_kv fdb-check-error ;

: fdb-doc-create ( key meta body -- doc )
    [ f void* <ref> ] 3dip
    [ dup length ] tri@
    [ fdb_doc_create fdb-check-error ] 7 nkeep 6 ndrop
    void* deref fdb_doc memory>struct ;

: fdb-doc-update ( doc meta body -- )
    [ void* <ref> ] 2dip
    [ dup length ] bi@
    fdb_doc_update fdb-check-error ;

: fdb-doc-free ( doc -- )
    fdb_doc_free fdb-check-error ;

: fdb-info ( -- info )
    get-handle
    fdb_info <struct> [ fdb_get_dbinfo fdb-check-error ] keep ;

: fdb-commit ( fdb_commit_opt_t -- )
    [ get-handle ] dip fdb_commit fdb-check-error ;

: fdb-maybe-commit ( fdb_commit_opt_t/f -- )
    [ fdb-commit ] when* ;

: fdb-commit-normal ( -- ) FDB_COMMIT_NORMAL fdb-commit ;

: fdb-commit-wal-flush ( -- ) FDB_COMMIT_MANUAL_WAL_FLUSH fdb-commit ;

FUNCTION: fdb_status fdb_rollback ( fdb_handle** handle_ptr, fdb_seqnum_t rollback_seqnum ) ;

! Call from within with-foresdb
: fdb-open-snapshot ( seqnum -- handle )
    [
        get-handle
        f void* <ref>
    ] dip [
        fdb_snapshot_open fdb-check-error
    ] 2keep drop void* deref <fdb-handle> ;

! fdb_rollback returns a new handle, so we
! have to replace our current handle with that one
! XXX: can't call dispose on old handle, library handles that
: fdb-rollback ( seqnum -- )
    [ get-handle void* <ref> ] dip
    [ fdb_rollback fdb-check-error ] 2keep drop
    void* deref <fdb-handle> fdb-current set ;


TUPLE: fdb-iterator < disposable handle ;

: <fdb-iterator> ( handle -- obj )
    fdb-iterator new-disposable
        swap >>handle ; inline

M: fdb-iterator dispose*
    handle>> fdb_iterator_close fdb-check-error ;


: fdb-iterator-init ( start-key end-key fdb_iterator_opt_t -- iterator )
    [ get-handle f void* <ref> ] 3dip
    [ [ dup length ] bi@ ] dip
    [ fdb_iterator_init fdb-check-error ] 7 nkeep 5 ndrop nip
    void* deref <fdb-iterator> ;

: fdb-iterator-init-none ( start-key end-key -- iterator )
    FDB_ITR_NONE fdb-iterator-init ;

: fdb-iterator-meta-only ( start-key end-key -- iterator )
    FDB_ITR_METAONLY fdb-iterator-init ;

: fdb-iterator-no-deletes ( start-key end-key -- iterator )
    FDB_ITR_NO_DELETES fdb-iterator-init ;

: check-iterate-result ( doc fdb_status -- doc/f )
    {
        { FDB_RESULT_SUCCESS [ void* deref fdb_doc memory>struct ] }
        { FDB_RESULT_ITERATOR_FAIL [ drop f ] }
        [ throw ]
    } case ;

: fdb-iterate ( iterator word -- doc )
    '[
        fdb_doc <struct> fdb_doc <ref>
        [ _ execute ] keep swap check-iterate-result
    ] call ; inline

! fdb_doc key, meta, body only valid inside with-forestdb
! so make a helper word to preserve them outside
TUPLE: doc seqnum key meta body deleted? offset size-ondisk ;

CONSTRUCTOR: <doc> doc ( seqnum key meta body deleted? offset size-ondisk -- obj ) ;

/*
! Example fdb_doc and converted doc
S{ fdb_doc
    { keylen 4 }
    { metalen 0 }
    { bodylen 4 }
    { size_ondisk 0 }
    { key ALIEN: 111e003b0 }
    { seqnum 5 }
    { offset 4256 }
    { meta f }
    { body ALIEN: 111d11740 }
    { deleted f }
}
T{ doc
    { seqnum 5 }
    { key "key5" }
    { body "val5" }
    { offset 4256 }
    { size-ondisk 0 }
}
*/

: alien/length>string ( alien n -- string/f )
    [ drop f ] [ memory>byte-array utf8 decode ] if-zero ;

: fdb_doc>doc ( fdb_doc -- doc )
    {
        [ seqnum>> ]
        [ [ key>> ] [ keylen>> ] bi alien/length>string ]
        [ [ meta>> ] [ metalen>> ] bi alien/length>string ]
        [ [ body>> ] [ bodylen>> ] bi alien/length>string ]
        [ deleted>> >boolean ]
        [ offset>> ]
        [ size_ondisk>> ]
    } cleave <doc> ;

: fdb-iterator-prev ( iterator -- doc/f ) \ fdb_iterator_prev fdb-iterate ;
: fdb-iterator-next ( iterator -- doc/f ) \ fdb_iterator_next fdb-iterate ;
: fdb-iterator-next-meta-only ( iterator -- doc/f ) \ fdb_iterator_next_metaonly fdb-iterate ;
: fdb-iterator-seek ( iterator key -- )
    dup length fdb_iterator_seek fdb-check-error ;

: with-fdb-iterator ( start-key end-key fdb_iterator_opt_t iterator-next quot: ( obj -- ) -- )
    [ fdb-iterator-init ] 2dip pick '[
        [ _ handle>> _ execute [ [ @ ] when* ] keep ] loop
        _ &dispose drop
    ] with-destructors ; inline

: with-fdb-normal-iterator ( start-key end-key quot -- )
    [ FDB_ITR_NONE \ fdb-iterator-next ] dip with-fdb-iterator ; inline

! XXX: broken?
: with-fdb-normal-meta-iterator ( start-key end-key quot -- )
    [ FDB_ITR_NONE \ fdb-iterator-next-meta-only ] dip with-fdb-iterator ; inline

! Do not try to commit here, as it will fail with FDB_RESULT_RONLY_VIOLATION
! fdb-current is weird, it gets replaced if you call fdb-rollback
! Therefore, only clean up fdb-current once, and clean it up at the end
: with-forestdb-handle ( handle quot fdb_commit_opt_t/f -- )
    '[
        _ fdb-current [
            [
                @
                _ fdb-maybe-commit
                fdb-current get &dispose drop
            ] [
                fdb-current get &dispose drop
                rethrow
            ] recover
        ] with-variable
    ] with-destructors ; inline

! Commit normal at the end
: with-forestdb-handle-commit-normal ( handle quot commit -- )
    FDB_COMMIT_NORMAL with-forestdb-handle ; inline

: with-forestdb-handle-commit-wal ( handle quot commit -- )
    FDB_COMMIT_MANUAL_WAL_FLUSH with-forestdb-handle ; inline

: with-forestdb-snapshot ( handle quot commit -- )
    f with-forestdb-handle ; inline

: with-forestdb-path ( path quot -- )
    [ absolute-path fdb-open ] dip with-forestdb-handle-commit-normal ; inline