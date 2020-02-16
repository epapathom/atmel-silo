/*
################## Project 3 ##################
#											  #
#        FILLING A SILO WITH MATERIAL         #
#											  #
#				   4/6/2018					  #	
#				  							  #
#	Authors:	Korkouti Dionys		          #
#				Papathomas Evangelos 	      #
#											  #
###############################################
*/

.include "m16def.inc"

;---Register Definitions---
.DEF STACK_REG = r16     ; Stack register
.DEF COM_CLEAR_REG = r17 ; 0xFF
.DEF CLEAR_REG = r18	 ; 0x00 (similar to clr)
.DEF TEMP_REG = r19      ; Temp register
.DEF A1L = r20           ; A1 low register
.DEF A1H = r21           ; A1 high register
.DEF B1L = r22           ; B1 low register
.DEF B1H = r23           ; B1 high register
.DEF B2L = r24           ; B2 low register
.DEF B2H = r25           ; B2 high register
.DEF B3L = r26           ; B3 low register
.DEF B3H = r27           ; B3 high register
.DEF B4L = r28           ; B4 low register
.DEF B4H = r29           ; B4 high register
.DEF COUNT=r30		 	 ; Overflow Counter for Timer1
.DEF ADC_F=r31			 ; ADC flag (Not Used)



rjmp SPI_INIT					; Jump to Stack Pointer Initialization
									
.org 0x002						; External Interupt Address Handler for INT0
	rjmp handlerSW2
.org 0x010						; Timer/Counter 1 Overflow Address Handler (Used as a Timer)
	rjmp timerOVFHandler
.org 0x012						; Timer/Counter 0 Overflow Address Handler (Used as a Counter)
	rjmp timer_fun_NS_handler
.org 0x01C						; ADC Conversion Complete Address Handler (Used for Silo 0)
	rjmp MyISRHandler_ADC

.cseg
	
	; Initialize stack pointer
	
	SPI_INIT:
	
	ldi TEMP_REG,low(RAMEND)
	out spl,TEMP_REG
	ldi TEMP_REG,high(RAMEND)
	out sph,TEMP_REG

	;---DO NOT CHANGE these regs---
	ldi COM_CLEAR_REG, 0xFF 	; Clear Ports (turn off the leds)
	ldi CLEAR_REG, 0x00 		; Clear (or turn on the leds)
	
	;---Set I/O---
	out ddra, CLEAR_REG 		; SET AS INPUT PORTA
	out ddrd, CLEAR_REG 		; SET AS INPUT PORTD
	out ddrb, COM_CLEAR_REG 	; SET AS OUTPUT PORTB
	
	;---Turn off the leds---
	out portb, COM_CLEAR_REG


	;---EXTERNAL Interupt Initializer---
	
	sei							; Enable any interrupts (I bit of SREG)
	
	ldi TEMP_REG, 0b00000010	; The falling edge of INT0 generates an interrupt request.	
	out MCUCSR, TEMP_REG		

	ldi TEMP_REG, 0b01000000	; External Interrupt Request 0 Enable for SW2 (Silo 2 Simulation);
	out GICR, TEMP_REG

; ########### -Programm Starts Here- ###########

start:
		; ---Initialize our project--- 

		ADC_A1:							; Silo 0 ADC Converter *Must be FILLED 
			ldi TEMP_REG, 0b01000000	
			out ADMUX, TEMP_REG			; AVCC with external capacitor at AREF pin | ADC0 Selected
			ldi TEMP_REG, 0b10000100 	
			out ADCSRA, TEMP_REG		; Enable ADC with division factor of 16
			sbi ADCSRA, ADSC			; START Conversion
			A1: 
			sbis ADCSRA, ADIF
			rjmp A1
			in A1L, ADCL				; Save the Result of ADC (Low & High)
			in A1H, ADCH
			sbi ADCSRA, ADIF			; Set Interrupt Flag ADIF

		ADC_B1:							; Silo 1 ADC Converter *Must be EMPTY
			ldi TEMP_REG, 0b01000001
			out ADMUX, TEMP_REG			; AVCC with external capacitor at AREF pin | ADC1 Selected
			ldi TEMP_REG, 0b10000100
			out ADCSRA, TEMP_REG		; Enable ADC with division factor of 16
			sbi ADCSRA, ADSC			; START Conversion
			B1:
			sbis ADCSRA, ADIF
			rjmp B1
			in B1L, ADCL				; Save the Result of ADC (Low & High)
			in B1H, ADCH
			sbi ADCSRA, ADIF			; Set Interrupt Flag ADIF

		ADC_B3:							; Silo 2 ADC Converter *Must be EMPTY
			ldi TEMP_REG, 0b01000011
			out ADMUX, TEMP_REG			; AVCC with external capacitor at AREF pin | ADC2 Selected
			ldi TEMP_REG, 0b10000100
			out ADCSRA, TEMP_REG		; Enable ADC with division factor of 16
			sbi ADCSRA, ADSC			; START Conversion
			B3:
			sbis ADCSRA, ADIF
			rjmp B3
			in B3L, ADCL				; Save the Result of ADC (Low & High)
			in B3H, ADCH		
			sbi ADCSRA, ADIF			; Set Interrupt Flag ADIF

		Silo1_Empty:					; CHECK if Silo 1 is EMPTY
			cp B1L, CLEAR_REG
			cpc B1H, CLEAR_REG
			breq Silo2_Empty			; If YES Check for Silo 2
			rjmp start					; If NO Go to START

		Silo2_Empty:					; CHECK if Silo 2 is EMPTY
			cp B3L, CLEAR_REG
			cpc B3H, CLEAR_REG
			breq Silo0_Filled			; If YES Check for Silo 0 
			rjmp start					; IF NO Go to START

		Silo0_Filled:					; CHECK is Silo 0 is FILLED

			cp A1L, CLEAR_REG
			cpc A1H, CLEAR_REG
			brne WaitForInput			; If Yes Wait for (START Button)
			rjmp start					; if No Go to START

		WaitForInput:					; START BUTTON
			sbic pind, 0				; If SW0 is NOT pressed, continue looping
				rjmp WaitForInput
			rjmp ReleaseSW0				; Else go to ReleaseSW0, to wait for release

		ReleaseSW0:						; Release START BUTTON
			in TEMP_REG, pind
			out portb, TEMP_REG
			sbis pind, 0
				rjmp ReleaseSW0

		SelectSilo1:					; SELECT SW1 for Silo 1 To Start the Procedure
			out portb,COM_CLEAR_REG
			
			sbis pind, 1				; If SW1 is pressed, go to ReleaseSW1.
				rjmp ReleaseSW1
			rjmp SelectSilo1			; If not, continue looping.

		ReleaseSW1:
			sbis pind, 1
				rjmp ReleaseSW1


; --- The Silo 0 and 1 are ready to Work ---

		rcall timer_fun_NS				; Call Counter 0 to start counting for interupt purposes (NONSTOP)

		StartProcess:
			ldi COUNT, 0x35				; Set number of Timer 1 Overflows (53 for 7sec simulation)
			ldi TEMP_REG, 0b01101111	
			out portb, TEMP_REG			; Set the Proper LEDS OPEN to PORTB
			rcall timer1_fun_counter	; Call Timer 1 for the delay (7sec)
			

		Continue:						; B5 is Activated | Enable The proper LEDS
			
			ldi TEMP_REG, 0b00001001
			out portb, TEMP_REG

		Silo1_Working:					; Silo 1 will start Working untill is empty
			
			rcall Check_Silo_0			; Check if Silo 0 is Filled (If Not ERROR)

			ADC_B2:						
			ldi TEMP_REG, 0b01000010	; ADC For silo 1 the same procedure as at the begining
			out ADMUX, TEMP_REG
			ldi TEMP_REG, 0b10000100
			out ADCSRA, TEMP_REG
			sbi ADCSRA, ADSC
			B2:
			sbis ADCSRA, ADIF
			rjmp B1
			in B1L, ADCL
			in B1H, ADCH
			sbi ADCSRA, ADIF
			
			
		Silo1_Filled:					;Check if Silo 1 is FULL

			cp B2L, CLEAR_REG
			cpc B2H, CLEAR_REG
			brne WaitForSilo2			; If YES Wait for SILO 2 to be enabled
			rjmp Silo1_Working			; If NO Continue Working
			
		
		WaitForSilo2:					; The User must ENABLE Silo 2 with SW2
			ldi TEMP_REG, 0b0110111
			out portb, TEMP_REG			; LEDS indication
			rcall delay
			ldi TEMP_REG, 0b0111111
			out portb, TEMP_REG
			rcall delay					; A small delay for better usability

			sbic pind, 2				; If SW2 is NOT pressed, continue looping
				rjmp WaitForSilo2
			rjmp ReleaseSW2				; Else go to ReleaseSW2, to wait for release

		ReleaseSW2:
			in TEMP_REG, pind
			out portb, TEMP_REG
			sbis pind, 2
				rjmp ReleaseSW0
	
		Silo2_Working:					; Silo 2 is now Working

			rcall Check_Silo_0			; Have a check if Silo 0 is still filled
						
			ldi TEMP_REG, 0b00101111	; Proper LEDS Indication
			out portb, TEMP_REG
	
			ADC_B4:
			ldi TEMP_REG, 0b01000100
			out ADMUX, TEMP_REG
			ldi TEMP_REG, 0b10000100
			out ADCSRA, TEMP_REG
			sbi ADCSRA, ADSC
			B4:
			sbis ADCSRA, ADIF
			rjmp B4
			in B4L, ADCL
			in B4H, ADCH
			sbi ADCSRA, ADIF
			
			
		Silo2_Filled:					; Check if Silo 2 is FILLED

			cp B2L, CLEAR_REG
			cpc B2H, CLEAR_REG
			brne FULL					; If YES then go to end of programm
			rjmp Silo2_Working			; If NO continue working
			
	
		FULL:
	
			ldi TEMP_REG, 0b01111101	; Proper LEDS Indication for both silo 1 and 2 (filled)
			out PORTB, TEMP_REG
			
			ldi COUNT, 0x35				; A 7sec delay for better usability (Showing the programm finished)

			rcall timer1_fun_counter

			rjmp SPI_INIT				; Jump to Stack Initializer
	

; ########### -Functions And Handlers for Interupts- ###########

	
		timer1_fun_counter:				; Timer 1 function for counting (Seconds depend on COUNT register);
			sei  			
			ldi TEMP_REG, 0b00000010	; Set the Timer 1 prescelar to 1/8 
			out TCCR1B, TEMP_REG

			ldi TEMP_REG, 0b00000101	; Enable the Timer 1 and Timer 0 Overflow Interupts
			out TIMSK, TEMP_REG

		loop:
			nop
			rjmp loop

		timerOVFHandler:				; The timer 1 Overflow Handler 
			dec COUNT
			brne timer1_fun_counter		; If the number is not done continue			
			reti						


	
		timer_fun_NS:					; Timer 0 function for SW1 SW4 SW5 SW7 Simulation
			sei
			ldi TEMP_REG, 0b00000010	; Set the prescaler to 1/8
			out TCCR0, TEMP_REG

			ldi TEMP_REG, 0b00000001	; Enable Timer 0
			out TIMSK, TEMP_REG

			ret
					
		timer_fun_NS_handler:			; Timer 0 Overflow Handler (NONSTOP)
			
			sbis pind, 1				; Silo 1 Simulator (Y1)
				rcall SW1_PRESSED 

			sbis pind, 4				; Motor Q1 Problem Simulator
				rcall SW4_PRESSED 		

			sbis pind, 5				; Motor Q2 Problem Simulator
				rcall SW5_PRESSED 
			
			sbis pind, 7				; STOP Switch Simulator
				rcall SW7_PRESSED 

			reti

	;--- Check Which Button is Pressed ---

		SW1_PRESSED:					
			sbis pind, 1
				rjmp SW1_PRESSED		; If SW1 is Pressed go to fun SW1_Pressed
			rjmp Silo1_Working			; If NOT continue working on Silo 1

		SW4_PRESSED:				
			sbis pind, 4
				rjmp SW4_PRESSED		; If SW4 is Pressed go to fun SW4_Pressed
			rcall ACK_Fun				; If NOT go to ACKNOWLEDGMENT function

		SW5_PRESSED:
			sbis pind, 5				
				rjmp SW5_PRESSED		; If SW5 is Pressed go to fun SW5_Pressed
			rcall ACK_Fun				; If NOT go to ACKNOWLEDGMENT function

		SW7_PRESSED:
			sbis pind, 7
				rjmp SW7_PRESSED		; If SW7 is Pressed go to fun SW1_Pressed
			
			ldi TEMP_REG, 0b00000001	; LED Output for indicating STOP 
			out PORTB, TEMP_REG

			rcall delay					; A small delay for better usability
			rjmp SPI_INIT				; Go to Stack Pointer Initializer
	
		ACK_Fun:						; ACK Function (Acknowledgment)
			ldi TEMP_REG, 0b00000001	
			out PORTB, TEMP_REG			; Proper LEDS Indicator

			sbic pind, 6 				; The USER must PRESS the ACK Button (SW6)
				rjmp ACK_Fun	
			
		WaitFor_ACK_Release:			; Wait to release the switch 6
			sbis pind, 6
				rjmp WaitFor_ACK_Release

		Period_1s_LED:					; LED 7 On and Off with 1sec period (ACK Simulator)
			ldi TEMP_REG, 0b00000000	
			out PORTB, TEMP_REG
	
			ldi COUNT, 0x07
			rcall timer1_fun_counter

			ldi TEMP_REG, 0b00000001	
			out PORTB, TEMP_REG
						
			ldi COUNT, 0x07
			rcall timer1_fun_counter

			rjmp Period_1s_LED			; Continue forever

;--- CHECK IF EMPTY SILO 0 Function ---

		Check_Silo_0:
		
			ldi TEMP_REG, 0b01000000	
			out ADMUX, TEMP_REG
			ldi TEMP_REG, 0b10001100 	; Enable the ADC Complete Interupt
			out ADCSRA, TEMP_REG
			sbi ADCSRA, ADSC
			C0: 
			sbis ADCSRA, ADIF
			rjmp C0
			in A1L, ADCL
			in A1H, ADCH
			sbi ADCSRA, ADIF
	
			ret

		MyISRHandler_ADC:				; ADC Complete Handler
										; Checking if Silo 0 is empty
			cp A1L, CLEAR_REG
			cpc A1H, CLEAR_REG
			breq ACK_Fun
				
			reti						; Return to the main programm

; --- Silo 2 Simulator (Y2) ---

		handlerSW2:						; The handler for the External interrupt INT2			
			
			rjmp Silo2_Working			; Jump to Silo2 Working
			

			
; --- The Delay Function (Less than 1 sec) ---
		delay:
    		ldi  r19, 3
    		ldi  r30, 8
    		ldi  r31, 120
		L1: dec  r31
   			brne L1
    		dec  r30
    		brne L1
    		dec  r19
    		brne L1
    		ret
			
