(module

  (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))

  (import "wasi_snapshot_preview1" "fd_write"
          (func $fd_write (param i32 i32 i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "random_get"
          (func $random_get (param i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "args_sizes_get"
          (func $args_sizes_get (param i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "args_get"
          (func $args_get (param i32 i32) (result i32)))

  ;; 0-131071: dynamic data
  ;; 131072-: static data
  (memory (export "memory") 4) ;; 4 wasm pages(262,144 bytes)

  (func $rand2stdout (param $size i32) (result i32)
    ;; input $size: size of the random bytes to get/write
    ;; result:
    ;;   - <0 on error

    ;; gets the random bytes
    i32.const 0 ;; the ptr to the buf to save the rand bytes
    local.get $size ;; the size of rand bytes to generate
    call $random_get
    i32.const 0
    i32.ne
    if
      i32.const -1
      return
    end

    i32.const 0x0001_0000 ;; pointer to this data
    i32.const 0           ;; the data(ptr to the random bytes)
    i32.store

    i32.const 0x0001_0004 ;; pointer to this data
    local.get $size       ;; the data(the size of the rand bytes)
    i32.store

    i32.const 1 ;; stdout
    i32.const 0x0001_0000 ;; pointer to the iovs
    i32.const 1 ;; single data
    i32.const 0x0001_2000 ;; pointer to the num bytes written
    call $fd_write
    i32.const 0
    i32.ne
    if
      i32.const -1
      return
    end

    i32.const 0
    return
  )

  (func $randpage2stdout (param $pages i32) (result i32)
    ;; input $pages: number of pages to write
    ;; result:
    ;;   - <0 on error

    (local $i i32)

    i32.const 0
    local.set $i

    loop
      local.get $pages
      local.get $i
      i32.le_u
      if
        i32.const 0
        return
      end

      i32.const 4096
      call $rand2stdout
      i32.const 0
      i32.ne
      if
        i32.const -1
        return
      end

      i32.const 1
      local.get $i
      i32.add
      local.set $i

      br 0
    end

    i32.const 0
    return
  )

  ;;                             0123456789abcdef01234567
  (data (i32.const 0x0002_0004) "unable to get arguments\n")
  (data (i32.const 0x0002_0000) "\08\01\00\00")

  (func $perr (param $pmsg i32) (param $size i32)
    i32.const 0 ;; pointer to this data
    local.get $pmsg ;; the data(pointer to the msg)
    i32.store

    i32.const 4 ;; pointer to this data
    local.get $size ;; the data(the size of the msg)
    i32.store

    i32.const 2 ;; stderr
    i32.const 0 ;; pointer to the iovs
    i32.const 1 ;; single string
    i32.const 1024 ;; pointer to the num bytes written
    call $fd_write
    i32.const 0
    i32.ne
    if
      ;; UNABLE TO WRITE THE ERROR MESSAGE
      unreachable
    end
  )

  (func $perr1_unable2get_args
     i32.const 0x0002_0004
     i32.const 0x0002_0000
     i32.load
     call $perr
  )

  (func $args_get_info (result i64 i32 i32)
    i32.const 0 ;; pointer to save the number of args
    i32.const 4 ;; pointer to save the size of args
    call $args_sizes_get
    i64.extend_i32_u

    ;; load the number of args
    i32.const 0
    i32.load

    ;; load the size
    i32.const 4
    i32.load
  )

  (func $dump_i32 (param $i i32) (result i32)
    i32.const 0x0001_0000
    local.get $i
    i32.store

    i32.const 0 ;; pointer to this data
    i32.const 0x0001_0000 ;; the data(pointer to the integer)
    i32.store

    i32.const 4 ;; pointer to this data
    i32.const 4 ;; the size of the integer
    i32.store

    i32.const 1 ;; stdout
    i32.const 0 ;; pointer to the iovs
    i32.const 1 ;; single data
    i32.const 0x0001_0100 ;; pointer to the num of bytes written
    call $fd_write
  )

  (func $dump_i64 (param $i i64) (result i32)
    i32.const 0x0001_0000
    local.get $i
    i64.store

    i32.const 0 ;; pointer to this data
    i32.const 0x0001_0000 ;; the data(pointer to the integer)
    i32.store

    i32.const 4 ;; pointer to this data
    i32.const 8 ;; the size of the integer
    i32.store

    i32.const 1 ;; stdout
    i32.const 0 ;; pointer to the iovs
    i32.const 1 ;; single data
    i32.const 0x0001_0100 ;; pointer to the num of bytes written
    call $fd_write
  )

  (func $ctou (param $ch i32) (result i32)
    i32.const 0x30
    local.get $ch
    i32.le_u

    local.get $ch
    i32.const 0x39
    i32.le_u
    i32.and

    i32.const 1
    i32.ne
    if
      i32.const -1
      return
    end

    local.get $ch
    i32.const 0x30
    i32.sub
  )

  (func $atoi (param $size i32) (param $ptr i32) (result i64)
    (local $i i32)
    (local $parsed i64)
    (local $ch2u i32)
    (local $mlt i64)

    ;; istr: "1048576"
    ;;        0123456

    local.get $size ;; e.g., 7
    local.get $ptr  ;; e.g., 0x0001_0000
    i32.add
    i32.const 1
    i32.sub
    local.set $i    ;; e.g., 0x0001_0006

    i64.const 0
    local.set $parsed

    i64.const 1
    local.set $mlt

    loop
      local.get $i
      local.get $ptr
      i32.lt_u
      if
        local.get $parsed
        return
      end

      local.get $i
      i32.load8_u
      call $ctou
      local.tee $ch2u
      i32.const 0
      i32.lt_s
      if
        i64.const -1
        return
      end

      local.get $ch2u
      i64.extend_i32_u
      local.get $mlt
      i64.mul
      local.get $parsed
      i64.add
      local.set $parsed

      local.get $i
      i32.const 1
      i32.sub
      local.set $i

      local.get $mlt
      i64.const 10
      i64.mul
      local.set $mlt

      br 0
    end

    i64.const -1
  )

  (func $strlen (param $pstr i32) (result i32)
    (local $len i32)
    (local $ptr i32)

    i32.const 0
    local.set $len

    local.get $pstr
    local.set $ptr

    loop
      local.get $ptr
      i32.load8_u
      i32.eqz
      if
        local.get $len
        return
      end

      i32.const 1
      local.get $ptr
      i32.add
      local.set $ptr

      i32.const 1
      local.get $len
      i32.add
      local.set $len

      br 0
    end

    i32.const 0
  )

  (func $get_pages_or_default
    (param $args_siz i32)
    (param $args_cnt i32)
    (param $alt i64)
    (result i64)

    (local $ptr2arg2 i32)

    ;; return default on unexpected args count
    local.get $args_cnt
    i32.const 2
    i32.ne
    if
      local.get $alt
      return
    end

    ;; return default on invalid args
    local.get $args_siz
    i32.const 32768
    i32.ge_u
    if
      local.get $alt
      return
    end

    i32.const 0x0000_0000 ;; pointer to pointers
    i32.const 0x0001_0000 ;; pointer to args
    call $args_get
    ;; return default on args get error
    i32.const 0
    i32.ne
    if
      local.get $alt
      return
    end

    ;; 0x0000_0000: pointer to the 1st arg(ignore)
    ;; 0x0000_0004: pointer to the 2nd arg(expected to be integer string)
    i32.const 0x0000_0004
    i32.load
    local.tee $ptr2arg2
    call $strlen
    local.get $ptr2arg2
    call $atoi
  )

  (func $main (export "_start")

    (local $args_err i64)
    (local $args_cnt i32)
    (local $args_siz i32)

    (local $rsize i64)

    call $args_get_info
    local.set $args_siz
    local.set $args_cnt
    local.tee $args_err

    ;; exit on args get error
    i64.const 0
    i64.ne
    if
      call $perr1_unable2get_args
      i32.const 1
      call $proc_exit
      return
    end

    local.get $args_siz
    local.get $args_cnt
    i64.const 1 ;; default: single page
    call $get_pages_or_default
    local.tee $rsize

    i64.const 0x0000_0000_ffff_ffff
    i64.and
    i32.wrap_i64
    call $randpage2stdout
    drop
  )

)
