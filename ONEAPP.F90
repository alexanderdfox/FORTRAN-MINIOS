! mini_os.f90
! A tiny "OS simulator" in Fortran demonstrating scheduler, processes, filesystem, and shell.
! Compile: gfortran -std=f2008 -O2 -o mini_os mini_os.f90
! Run: ./mini_os

module os_types
  implicit none
  integer, parameter :: MAX_PROCS = 32
  integer, parameter :: MAX_FILE_LEN = 1024
  integer, parameter :: MAX_MSGS = 16
  type :: process_t
    integer :: pid = 0
    character(len=:), allocatable :: name
    integer :: state = 0    ! 0=ready,1=running,2=blocked,3=terminated
    integer :: pc = 1       ! simple program counter for demo tasks
    integer :: mem_used = 0
    logical :: active = .false.
  end type process_t

  type :: file_t
    character(len=:), allocatable :: name
    character(len=:), allocatable :: data
  end type file_t

  type :: msg_t
    integer :: from = 0
    integer :: to = 0
    character(len=:), allocatable :: body
  end type msg_t
end module os_types

module mini_os
  use os_types
  implicit none
  type(process_t) :: procs(MAX_PROCS)
  integer :: next_pid = 1
  integer :: proc_count = 0
  integer :: current = 0

  type(file_t), allocatable :: fs(:)
  integer :: fs_count = 0

  type(msg_t), allocatable :: msgs(:)
  integer :: msg_count = 0

contains

  subroutine os_init()
    integer :: i
    do i = 1, MAX_PROCS
      procs(i)%pid = 0
      procs(i)%active = .false.
      procs(i)%state = 3
    end do
    allocate(fs(0))
    fs_count = 0
    allocate(msgs(0))
    msg_count = 0
    call make_file("readme.txt", "Welcome to MiniOS (Fortran). Type 'help' for commands.\n")
    call spawn("init_task", init_task)
    call spawn("idle", idle_task)
  end subroutine os_init

  subroutine make_file(fname, content)
    character(len=*), intent(in) :: fname, content
    fs_count = fs_count + 1
    call move_alloc(fs, fs, stat=ignore) ! trick to resize
    if (allocated(fs)) then
      call extend_filesys(fname, content)
    else
      allocate(fs(1))
      fs(1)%name = fname
      fs(1)%data = content
    end if
  end subroutine make_file

  subroutine extend_filesys(fname, content)
    character(len=*), intent(in) :: fname, content
    type(file_t), allocatable :: tmp(:)
    integer :: n
    n = fs_count
    allocate(tmp(n))
    tmp = fs
    deallocate(fs)
    allocate(fs(n))
    fs = tmp
    fs(n)%name = fname
    fs(n)%data = content
  end subroutine extend_filesys

  function find_proc_slot() result(slot)
    integer :: slot, i
    slot = 0
    do i = 1, MAX_PROCS
      if (.not. procs(i)%active) then
        slot = i
        return
      end if
    end do
  end function find_proc_slot

  subroutine spawn(pname, entry)
    character(len=*), intent(in) :: pname
    procedure(), pointer :: entry
    integer :: s
    s = find_proc_slot()
    if (s == 0) then
      print *, "PROCS: no free slot"
      return
    end if
    procs(s)%pid = next_pid
    next_pid = next_pid + 1
    procs(s)%name = pname
    procs(s)%state = 0
    procs(s)%pc = 1
    procs(s)%mem_used = 4
    procs(s)%active = .true.
    proc_count = proc_count + 1
  end subroutine spawn

  subroutine kill_proc(pid)
    integer, intent(in) :: pid
    integer :: i
    do i = 1, MAX_PROCS
      if (procs(i)%active .and. procs(i)%pid == pid) then
        procs(i)%active = .false.
        procs(i)%state = 3
        proc_count = max(0, proc_count - 1)
        print *, "OS: killed pid", pid
        return
      end if
    end do
    print *, "OS: pid not found"
  end subroutine kill_proc

  subroutine schedule_tick()
    ! Simple round-robin cooperative scheduler
    integer :: i, start, found
    if (proc_count == 0) return
    if (current == 0) start = 1 else start = current + 1
    found = 0
    do i = 0, MAX_PROCS-1
      integer :: idx
      idx = mod(start-1 + i, MAX_PROCS) + 1
      if (procs(idx)%active .and. procs(idx)%state == 0) then
        current = idx
        procs(idx)%state = 1
        found = 1
        call run_process(idx)
        if (procs(idx)%state == 1) procs(idx)%state = 0
        exit
      end if
    end do
    if (.not. found) then
      ! maybe all blocked; wake idle
      do i = 1, MAX_PROCS
        if (procs(i)%active .and. procs(i)%name == "idle") then
          current = i
          procs(i)%state = 1
          call run_process(i)
          procs(i)%state = 0
          exit
        end if
      end do
    end if
  end subroutine schedule_tick

  subroutine run_process(index)
    integer, intent(in) :: index
    ! In this simulated environment, we just call known named tasks by pid index.
    character(len=:), allocatable :: nm
    nm = procs(index)%name
    select case (trim(nm))
    case ("init_task")
      call init_task_body(index)
    case ("idle")
      call idle_body(index)
    case default
      ! user spawned tasks: attempt to run pre-defined demo tasks
      call user_task_body(index)
    end select
  end subroutine run_process

  subroutine init_task()
    ! placeholder - applications spawn using spawn("name", ptr)
  end subroutine init_task

  subroutine idle_task()
  end subroutine idle_task

  subroutine init_task_body(idx)
    integer, intent(in) :: idx
    integer :: done
    done = 0
    ! init: create some files and a demo process
    if (fs_count < 1) then
      call make_file("hello.txt","This is MiniOS. Enjoy!\n")
      call make_file("notes.txt","- Use 'ls' to list files\n- 'cat <file>' to view\n- 'ps' to view processes\n- 'run demo' to spawn demo process\n")
    end if
    ! the init task should run shell for the user
    call shell_loop()
    ! when shell exits, terminate init
    procs(idx)%active = .false.
    procs(idx)%state = 3
  end subroutine init_task_body

  subroutine idle_body(idx)
    integer, intent(in) :: idx
    ! idle: just pause (we're in userland so sleep a bit)
    call sleep_seconds(1)
  end subroutine idle_body

  subroutine user_task_body(idx)
    integer, intent(in) :: idx
    ! A tiny demo workload that prints a message then finishes
    print *, "Process", procs(idx)%pid, "(", trim(procs(idx)%name), ") running demo workload..."
    ! simulate work
    call sleep_seconds(1)
    procs(idx)%active = .false.
    procs(idx)%state = 3
    print *, "Process", procs(idx)%pid, "terminated."
  end subroutine user_task_body

  subroutine sleep_seconds(s)
    integer, intent(in) :: s
    integer :: i, j
    do i = 1, s
      call system_pause(0.1)  ! small busy wait
    end do
  end subroutine sleep_seconds

  subroutine system_pause(sec)
    real, intent(in) :: sec
    real :: t0, t1
    call cpu_time(t0)
    do
      call cpu_time(t1)
      if (t1 - t0 >= sec) exit
    end do
  end subroutine system_pause

  subroutine shell_loop()
    character(len=256) :: line
    logical :: keep
    keep = .true.
    do while (keep)
      write(*,'(A)', advance='no') "mini-os> "
      if ( .not. read_line(line) ) then
        keep = .false.
        exit
      end if
      call handle_cmd(adjustl(trim(line)), keep)
      ! schedule other processes between commands
      call schedule_tick()
    end do
  end subroutine shell_loop

  logical function read_line(out)
    character(len=*), intent(out) :: out
    character(len=1024) :: tmp
    out = ""
    if (iostat=0) then
      ! use READ with iostat to avoid crash on EOF
    end if
    read(*,'(A)', iostat=readerr) tmp
    if (readerr /= 0) then
      read_line = .false.
    else
      out = trim(tmp)
      read_line = .true.
    end if
  end function read_line

  subroutine handle_cmd(cmd, keep)
    character(len=*), intent(in) :: cmd
    logical, intent(inout) :: keep
    character(len=80) :: token, arg
    integer :: s, pid
    if (len_trim(cmd) == 0) return
    call split_cmd(cmd, token, arg)
    select case (trim(token))
    case ("help")
      call cmd_help()
    case ("ls")
      call cmd_ls()
    case ("cat")
      call cmd_cat(trim(arg))
    case ("ps")
      call cmd_ps()
    case ("run")
      if (len_trim(arg) == 0) then
        print *, "usage: run <name>"
      else
        call spawn(trim(arg), user_task)  ! pointer not used but purposely simple
      end if
    case ("kill")
      read(arg,*) pid
      call kill_proc(pid)
    case ("exit")
      keep = .false.
    case default
      print *, "Unknown command. Type 'help'."
    end select
  end subroutine handle_cmd

  subroutine split_cmd(line, cmd, arg)
    character(len=*), intent(in) :: line
    character(len=*), intent(out) :: cmd, arg
    integer :: p
    p = index(line, ' ')
    if (p == 0) then
      cmd = line
      arg = ""
    else
      cmd = line(1:p-1)
      arg = adjustl(line(p+1:))
    end if
  end subroutine split_cmd

  subroutine cmd_help()
    print *, "MiniOS help:"
    print *, "  ls           - list files"
    print *, "  cat <file>   - show file contents"
    print *, "  ps           - list processes"
    print *, "  run <name>   - spawn a demo process named <name>"
    print *, "  kill <pid>   - kill process id"
    print *, "  exit         - exit shell (shuts init)"
  end subroutine cmd_help

  subroutine cmd_ls()
    integer :: i
    if (fs_count == 0) then
      print *, "(no files)"
      return
    end if
    do i = 1, fs_count
      write(*,'(A)') trim(fs(i)%name)
    end do
  end subroutine cmd_ls

  subroutine cmd_cat(fname)
    character(len=*), intent(in) :: fname
    integer :: i
    logical :: found
    found = .false.
    do i = 1, fs_count
      if (trim(fs(i)%name) == trim(fname)) then
        write(*,'(A)') trim(fs(i)%data)
        found = .true.
        exit
      end if
    end do
    if (.not. found) print *, "cat: file not found"
  end subroutine cmd_cat

  subroutine cmd_ps()
    integer :: i
    print '(A)', "PID  NAME        STATE"
    do i = 1, MAX_PROCS
      if (procs(i)%active) then
        write(*,'(I4,2X,A12,2X,I2)') procs(i)%pid, trim(procs(i)%name), procs(i)%state
      end if
    end do
  end subroutine cmd_ps

  ! dummy: user_task is placeholder pointer target
  subroutine user_task()
  end subroutine user_task

end module mini_os

program main
  use mini_os
  implicit none
  call os_init()
  ! simple main loop: schedule until no processes left (init can spawn)
  do while (proc_count > 0)
    call schedule_tick()
  end do
  print *, "MiniOS shutting down."
end program main
