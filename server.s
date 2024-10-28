.intel_syntax noprefix
.globl _start

.section .text

_start:
    mov rdi, 2 	# AF_INET
    mov rsi, 1 	# SOCK_STREAM
    mov rdx, 0
    mov rax, 0x29
    syscall		# socket

    test rax, rax
    js socket_error

    # Set up sockaddr_in
    mov dword ptr [sockaddr_in], 2           # sin_family = AF_INET
    mov word ptr [sockaddr_in + 2], 0x5000   # sin_port = htons(80) = 0x5000
    mov dword ptr [sockaddr_in + 4], 0       # sin_addr.s_addr = INADDR_ANY

    lea rsi, [sockaddr_in]
    mov rdi, rax
    mov rdx, 0x10 # addrlen (16)
    mov rax, 0x31
    syscall		# bind

    test rax, rax
    js bind_error

    mov rsi, 0
    mov rax, 0x32
    syscall     # listen (fd still in rdi)

    mov r8, rdi # Store fd of socket

accept_connection:
    mov rdi, r8
    mov rsi, 0
    mov rdx, 0
    mov rax, 0x2B
    syscall     # accept

    mov r9, rax # Store fd of connection

    mov rax, 0x39
    syscall

    test rax, rax
    jz child_process

parent_process:
    mov rdi, r9
    mov rax, 0x3
    syscall     # close connection to go back to accepting
    jmp accept_connection

child_process:
    mov rdi, r8
    mov rax, 0x3
    syscall     # close socket

    mov rdi, r9
    lea rsi, [request_buffer]
    mov rdx, 1024 # Request buffer size
    mov rax, 0x0
    syscall     # read

    # Reading the requested file
    lea rdi, [request_buffer]
    call check_request # Get the requested file's path
    
    mov rdi, rax
    mov rsi, 0 # Read-only
    mov rax, 0x2
    syscall     # open 

    test rax, rax # Check if file does not exist
    js file_not_found

    mov rdi, rax
    lea rsi, [file_content]
    mov rdx, 104857600
    mov rax, 0x0
    syscall     # read

    mov r10, rax # Store number of bytes

    mov rax, 0x3
    syscall     # close requested file (fd still in rdi)

    mov rdi, r9
    lea rsi, [http_ok]
    mov rdx, 19 # Length of http_ok
    mov rax, 0x1
    syscall     # write

    lea rsi, [file_content]
    mov rdx, r10
    mov rax, 0x1
    syscall     # write (fd still in rdi)

close_connection:
    mov rax, 0x3
    syscall     # close connection (fd still in rdi)

    mov rdi, 0
exit:
    mov rax, 0x3c
    syscall		# exit


file_not_found:
    mov rdi, r9
    lea rsi, [http_not_found]
    mov rdx, 26 # Length of http_not_found
    mov rax, 0x1
    syscall     # write

    jmp close_connection


socket_error:
    mov rdi, 1
    jmp exit


bind_error:
    mov rdi, 2
    jmp exit


check_request:
    # Input: rdi = pointer to request_buffer
    # Output: rax = pointer to server_path
    mov rcx, 0x20544547 # "GET "
    cmp dword ptr [rdi], ecx
    jne invalid_request
    add rdi, 4
    lea rsi, [server_path + 0] # Change here if different path
    mov rcx, 0

append_path: # Searching for the end of the path
    mov al, byte ptr [rdi + rcx]
    cmp al, ' '
    je path_end
    mov byte ptr [rsi + rcx], al
    inc rcx
    cmp rcx, 256
    jl append_path

path_end:
    mov byte ptr [rsi + rcx], 0 # Null-terminate path
    lea rax, [server_path]
    ret

invalid_request:
    xor rax, rax # Null rax if invalid request
    ret

.section .bss
sockaddr_in:
    .space 16
request_buffer:
    .space 1024
file_content:
    .space 104857600 # 100 Mb

.section .data
server_path:
    .string "" # If you change this line the offset
    .space 256 # in check_request has to also be updated
http_ok:
    .string "HTTP/1.0 200 OK\r\n\r\n" # len = 19
http_not_found:
    .string "HTTP/1.0 404 Not Found\r\n\r\n" # len = 26
