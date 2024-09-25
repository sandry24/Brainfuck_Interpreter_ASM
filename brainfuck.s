.text

perms: 	.asciz "r"
scfmt:  .asciz "%c"

.global main 


# next(current, end) - returns current-1 if it doesnt go further than end
next:
	decq 	%rdi
	cmpq 	%rdi, %rsi 		# if reached end
	je 		next_exit_early # end the program
	movq 	%rdi, %rax 		# return value
	ret
next_exit_early:
	movq 	$0, %rdi # set system exit status to 0
	call 	exit

# prev(current, start) - returns current+1 if it doesnt go above start
prev:
	incq 	%rdi
	cmpq 	%rdi, %rsi   	# if reached start
	je 		prev_exit_early # end the program
	movq 	%rdi, %rax		# return value
	ret
prev_exit_early:
	movq 	$1, %rdi # set system exit status to 1
	call 	exit


# jmpnext(current, end) - returns the memory address of the matching closed bracket
jmpnext:
	# prologue
	pushq 	%rbp 
	movq 	%rsp, %rbp 

	# save callee-saved registers in stack
	subq 	$32, %rsp 
	movq 	%r12, -8(%rbp)
	movq 	%r13, -16(%rbp) 
	movq 	%r14, -24(%rbp)

	movq 	%rdi, %r12 # r12 will hold the current address
	movq 	%rsi, %r13 # r13 will hold the end
	movq 	$0, %r14   # r14 will hold the counter
jmpnext_loop:
	cmpb 	$'[, (%r12) 	# if *(r12) == '[', r14++
	jne 	jmpnext_if_not_open_bracket
	incq 	%r14
	jmp 	jmpnext_end_if
jmpnext_if_not_open_bracket:
	cmpb 	$'], (%r12) 	# if *(r12) == ']', r14--
	jne 	jmpnext_end_if
	decq 	%r14
jmpnext_end_if:
	cmpq 	$0, %r14 		# if counter is 0, we found the matching bracket
	je 		jmpnext_end
	movq 	%r12, %rdi 
	movq 	%r13, %rsi
	call 	next 			# go to next instruction
	movq 	%rax, %r12 
	jmp 	jmpnext_loop 	# loop
jmpnext_end:
	movq 	%r12, %rax 		# return value

	movq 	-8(%rbp),  %r12 # give callee-saved registers their value back
	movq 	-16(%rbp), %r13
	movq 	-24(%rbp), %r14

	#epilogue
	movq 	%rbp, %rsp
	popq 	%rbp
	ret


# jmpprev(current, start) - returns the memory address of the matching open bracket
jmpprev:
	# prologue
	pushq %rbp 
	movq %rsp, %rbp 

	# save callee-saved registers in stack
	subq 	$32, %rsp 
	movq 	%r12, -8(%rbp)
	movq 	%r13, -16(%rbp) 
	movq 	%r14, -24(%rbp)

	movq 	%rdi, %r12 # r12 will hold the current address
	movq 	%rsi, %r13 # r13 will hold the start
	movq 	$0, %r14   # r14 will hold the counter
jmpprev_loop:
	cmpb 	$'[, (%r12) 	# if *(r12) == '[', r14++
	jne 	jmpprev_if_not_open_bracket
	incq 	%r14
	jmp 	jmpprev_end_if
jmpprev_if_not_open_bracket:
	cmpb 	$'], (%r12) 	# if *(r12) == ']', r14--
	jne 	jmpprev_end_if
	decq 	%r14
jmpprev_end_if:
	cmpq 	$0, %r14		# if counter is 0, we found the matching bracket
	je 		jmpprev_end
	movq 	%r12, %rdi 
	movq 	%r13, %rsi
	call 	prev 			# go to next instruction
	movq 	%rax, %r12 
	jmp 	jmpprev_loop 	# loop
jmpprev_end:
	movq 	%r12, %rax 		# return value

	movq 	-8(%rbp),  %r12 # give callee-saved registers their value back
	movq 	-16(%rbp), %r13
	movq 	-24(%rbp), %r14

	#epilogue
	movq 	%rbp, %rsp
	popq 	%rbp
	ret	

# usage: ./<name_of_program> <name_of_file>
main: 
	# prologue
	pushq 	%rbp 			# push the base pointer
	movq 	%rsp, %rbp 		# copy stack pointer value to base pointer

	subq 	$32, %rsp     	# Save the values of callee-saved registers
	movq 	%r12, -8(%rbp)
	movq 	%r13, -16(%rbp)
	movq 	%r14, -24(%rbp)
	movq 	%r15, -32(%rbp)

	# Allocate 30'000 bytes to stack for data (wiki documentation)
	subq 	$30000, %rsp

	# Set all the values in the data stack to 0
	leaq 	-30032(%rbp), %rax
	leaq 	-32(%rbp),    %rcx

set_all_stack_values_to_zero_loop:
	movb 	$0, (%rax)
	incq 	%rax
	cmpq 	%rax, %rcx
	jne 	set_all_stack_values_to_zero_loop


	# Read all the instructions from the file
	movq 	8(%rsi), %r12 	# move argv[1] -> r12

	# Open the file
	movq 	%r12, %rdi
	movq 	$perms, %rsi
	call 	fopen
	movq 	%rax, %r13 			# pointer to our file

	leaq 	-30032(%rbp), %r14  # r14 -> beggining of instruction list
read_file_until_done_loop:
	cmpq 	%r14, %rsp 				# if we didnt reach the end of the stack  
	jne 	read_file_no_add_stack 	# read the instruction
	subq 	$16, %rsp 				# else increase the stack size

read_file_no_add_stack:
	decq 	%r14	
	movq 	%r14, %rdi
	movq 	$1,   %rsi
	movq 	$1,   %rdx
	movq 	%r13, %rcx
	call 	fread
	cmpq 	$0, %rax
	jne 	read_file_until_done_loop


	leaq 	-30032(%rbp), %r12  # r12 -> stack pointer at position 0
	leaq 	-30033(%rbp), %r13  # r13 -> instruction pointer at position 0
                             	# r14 -> instruction list end (already set)

	# Execute the code into itself
executing_instructions_loop:

	cmpb     $'>,   (%r13)
	je       stack_pointer_increase
	cmpb     $'<,   (%r13)
	je       stack_pointer_decrease
	cmpb     $'+,   (%r13)
	je       current_value_increase
	cmpb     $'-,   (%r13)
	je       current_value_decrease
	cmpb     $',,   (%r13)
	je       scan_current_value
	cmpb     $'.,   (%r13)
	je       print_current_value
	cmpb     $'[,   (%r13)
	je       open_bracket
	cmpb     $'],   (%r13)
	je       closed_bracket

	jmp     execute_end_case    # Ignore the character if it's not instruction.
	stack_pointer_increase:
		incq    %r12
		jmp     execute_end_case
	stack_pointer_decrease:
		decq    %r12
		jmp     execute_end_case
	current_value_increase:
		incb    (%r12)
		jmp     execute_end_case
	current_value_decrease:
		decb    (%r12)
		jmp     execute_end_case
	scan_current_value:
		movq    $0,     %rax    # rax = 0
		movq    $scfmt, %rdi    # rdi = "%c"
		movq    %r12,   %rsi    # rsi = r12 = stack pointer
		call    scanf
		jmp     execute_end_case
	print_current_value:
		movq    $0,     %rax    # rax = 0
		movq    $scfmt, %rdi    # rdi = "%c"
		movb    (%r12), %sil    # rsi = *r12 = current value
		call    printf
		jmp     execute_end_case
	open_bracket:
		cmpb    $0,     (%r12)  # Executes only if current value is 0
		jne     execute_end_case
		movq    %r13, %rdi      # rdi = instruction pointer
		movq    %r14, %rsi      # rsi = instruction list end
		call    jmpnext
		movq    %rax, %r13      # r13 = new instruction pointer
		jmp     execute_end_case
	closed_bracket:
		cmpb    $0,     (%r12)  # Executes only if current value is not 0
		je      execute_end_case
		movq    %r13,           %rdi      # rdi = instruction pointer
		leaq    -30032(%rbp),   %rsi      # rsi = instruction list start
		call    jmpprev
		movq    %rax, %r13                # r13 = new instruction pointer
	execute_end_case:

	movq    %r13, %rdi          # rdi = instruction pointer
	movq    %r14, %rsi          # rsi = instruction list end
	call    next
	movq    %rax, %r13          # r13 = new instruction pointer
	jmp 	executing_instructions_loop

	# Return callee-saved their original value back
	movq 	-8(%rbp),  %r12
	movq 	-16(%rbp), %r13
	movq 	-24(%rbp), %r14
	movq 	-32(%rbp), %r15 

	# epilogue
	movq 	%rbp, %rsp 			# clear local variables from stack
	popq 	%rbp 				# restore base pointer location

	movq 	$0, %rdi 			# set system exit status to 0
	call 	exit
