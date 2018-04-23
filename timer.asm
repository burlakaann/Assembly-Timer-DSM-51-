

CSDS16	EQU	0FF30H	;adres zatrzasku wyboru wskaŸnika/wyœwietlacza
CSDB16	EQU	0FF38H	;adres zatrzasku wyboru segmentów/wzorków

SEGOFF	BIT	P1.6	;ten bit w³¹cza wyœwietlacze

CZAS  EQU 7AH
CZAS1 EQU 79H
LICZNIK EQU 75H
LICZNIK1 EQU 74H

LDTEST	EQU	P1.7	;w³¹cza (0) / wy³¹cza (1) diodê TEST
SEQKEY	EQU	P3.5	;testuje naciœniêcie (1) klawisza KSQ

KeyCount	EQU	73H	;zlicza powtórzenia klawisza
AgrKey	EQU	72H	;agregowany stan klawiatury sekwencyjnej
PrvKey	EQU	71H	;poprzedni stan klawiatury sekwencyjnej
Tryb    BIT     70H     ;(1) tryb normalny,(0) tryb ustawiania



T0IB	BIT	7FH		;timer 0 interrupt bit
;=======================================
;
;	RESET
;
	ORG	00H	;reset
	LJMP	START

;=======================================
;	TIMER 0 INTERRUPT
	ORG	0BH

	LJMP	TI0MAIN	;w ten sposób omijamy ograniczenie do 8 bajtów
;=======================================
;	TIMER 0 INTERRUPT MAIN
	ORG	0B0H			;od B0h do 100h jest 80 bajtów, na pewno wystarczy

TI0MAIN:
	PUSH	ACC			;zabezpieczamy wykorzystywane rejestry
	PUSH	PSW			;

	MOV	TH0, #255 - 3	;wartoœæ typowa

	MOV	A, #256 - 154 + 1	; + 1 aby nadrobiæ stratê
	ADD	A, TL0		;uwzglêdnia opóŸnienie wywo³ania przerwania
	MOV	TL0, A		;TL0 ustawione w³aœciwie

	JNC	TI0MAIN_TH0_OK	;je¿eli nie Carry to jest OK
	INC	TH0			;wpr podbijamy TH0 w stosuku do wartoœci typowej

TI0MAIN_TH0_OK:			;TH0 ustawione w³aœciwie
	POP	PSW			;odzyskujemy wykorzystywane rejestry
	POP	ACC			;

	SETB	T0IB			;informujemy pêtlê g³ówn¹ o przerwaniu

	RETI				;powrót z przerwania

;=======================================

;	PROGRAM
;
	ORG	100H			;program

START:

      SETB Tryb
      MOV CZAS1, #00H
      MOV CZAS1-1, #00H
      MOV CZAS1-2, #00H
      MOV LICZNIK, #00H
      MOV LICZNIK1, #00H
      MOV KeyCount, #00H
      MOV AgrKey, #00H

      MOV	IE,	#00h	;blokada wszystkich przerwañ

		MOV	TMOD,	#71h	;T1.GATE=0 T1.C/T=C T1.MODE=3 T0.GATE=0 T1.C/T=T T0.MODE=1
		MOV	TCON,	#10h	;m.in. blokada zliczania przez T1, aktywuje zliczanie przez timer 0
		SETB	ET0		;aktywuje przerwanie od timer 0
		SETB	EA		;globalne zezwolenie na obs³ugê przerwañ



;adres zatrzasku wyboru wskaŸników do DPTR
;na razie zmienia siê niewiele, przenosimy funkcje kontrolne do rejestrów R6 i R7
;¿eby zwolniæ akumulator do innch zadañ,
;w dalszym ci¹gu ten sam wzorek na wszystkich wyœwietlaczach

LoopIni:
	MOV	R0, #CZAS		;zaczynamy od najm³odszego wyœwietlacza
						;R0 przyjmuje wartoœci 1, 2, 3, 4, 5, 6, 7
	MOV	R6, #32			;to jest najm³odszy wyœwietlacz bitowo
	MOV AgrKey, #00H						;R6 przyjmuje wartoœci 1, 2, 4, 8, 16, 32, 64

LoopRun:
	;DJNZ R4, LoopRun
	

        JNB	T0IB, LoopRun	;czeka na przerwanie
        CLR	T0IB		;zapomina ¿e by³o przerwanie

        JNB Tryb, Ustawianie

        INC LICZNIK1
        MOV A, LICZNIK1
        CJNE A, #0FFH, DALEJ
	MOV LICZNIK1, #00H
        INC LICZNIK

DALEJ:

		MOV A, LICZNIK1
		CJNE A, #0E8H, DALEJ2

		MOV A, LICZNIK
		CJNE A, #3H, DALEJ2

		MOV LICZNIK1 , #00H
		MOV LICZNIK, #00H
                LCALL PO1S

        ;PRZERWANIE 1/1000 SEKUNDY

DALEJ2:
        
        LCALL Refresh
Ustawianie:



	MOV	A, @R0			;maska bitowa wybieraj¹ca wyœwietlacz do A
        
        MOV	DPTR, #WZORY	;adres wzorków do DPTR
	MOVC	A, @A+DPTR	;wzorek do A

	CJNE R0, #CZAS+1, Bez_kropkiH
	ORL A, #10000000b
Bez_kropkiH:

	CJNE R0, #CZAS+3, Bez_kropkiM
	ORL A, #10000000b
Bez_kropkiM:

	MOV	DPTR, #CSDB16	;adres zatrzasku wzorków do DPTR
	SETB	SEGOFF
	MOVX	@DPTR, A	;wzorek do zatrzasku

	MOV	DPTR, #CSDS16

	MOV	A, R6			;maska bitowa wybieraj¹ca wyœwietlacz do A
	MOVX	@DPTR, A	;wybierz wskaŸnik
        CLR SEGOFF
        JNB	SEQKEY, LoopRunNoKey	;je¿eli klawisz odpowiadaj¹cy masce w R6
						;nie jest naciœniêty

	ORL	AgrKey, A		;agreguj bit naciœniêtego klawisza do AgrKey

LoopRunNoKey:



	RR	A				;w nastêpnym obrocie pêtli wybierz nastêpny,
	MOV	R6, A			;starszy wyœwietlacz - i zapamiêtaj to w R6

	INC	R0				;przestaw wskaŸnik na starszy wyœwietlacz
	CJNE	R0, #CZAS+6, LoopRun	;"8" w R0 oznacza miniêcie diod F1-ER

        MOV	A, AgrKey		;po obiegniêciu wszystkich wyœwietlaczy/klawiszy
					;sprawdzamy stan klawiatury

	JZ	LoopRunNewKey	;je¿eli nic nie jest naciœniête

LoopRunKey:
	CJNE	A, PrvKey, LoopRunNewKey	;je¿eli stan klawiatury siê zmieni³

	MOV	A, KeyCount		;je¿eli licznik powtórzeñ ma wartoœæ 0 to znaczy
	JZ	LoopIni		;¿e klawisz ju¿ wczeœniej zosta³ zauwa¿ony i obs³u¿ony

	DJNZ	KeyCount, LoopIni	;klawiatura mo¿e jeszcze nie byæ ustabilizowana
					;wiêc ponownie zacznij od najm³odszego wyœwietlacza

					;licznik powtórzeñ akurat osi¹gn¹³ wartoœæ 0
        MOV A, AgrKey
	ANL A, #00000001b
	JZ NoEnter
	SETB Tryb


NoEnter:
	MOV A, AgrKey
	ANL A, #00000010b
        JZ NoEsc

        JB Tryb,NoZer
	MOV CZAS1,#00000000B
	MOV CZAS1-1,#00000000B
	MOV CZAS1-2,#00000000B
	MOV LICZNIK1, #00000000B
	MOV LICZNIK, #00000000B
NoZer:
        JNB Tryb,NoEsc
	CLR Tryb

			;tutaj mo¿na regularnie obs³u¿yæ klawiaturê, w tym programie
					;ogranicza siê to wy³¹cznie do odwrócenia stanu diody TEST
NoEsc:


        LJMP	LoopIni		;ponownie zacznij od najm³odszego wyœwietlacza

LoopRunNewKey:
	MOV	KeyCount, #25	;odnawiamy licznik powtórzeñ
	MOV	PrvKey, AgrKey	;zapamiêtuje "poprzedni" stan klawiatury
	LJMP	LoopIni		;ponownie zacznij od najm³odszego wyœwietlacza


	PO1S:



		MOV A, CZAS1
		ADD A, #1
		DA A
		MOV CZAS1,A
		CJNE A, #60H, SKOK
		MOV CZAS1, #00H


		MOV A, CZAS1-1
		ADD A, #1
		DA A
		MOV CZAS1-1,A

		CJNE A, #60H, SKOK
		MOV CZAS1-1, #00H


		MOV A, CZAS1-2
		ADD A, #1
		DA A
		MOV CZAS1-2,A
		CJNE A, #24H, SKOK
		MOV CZAS1-2, #00H
SKOK:
                RET

Refresh:
     		MOV A, CZAS1
     		ANL A, #00001111B
		MOV CZAS+5, A

		MOV A, CZAS1
		ANL A, #11110000B
                SWAP A
		MOV CZAS+4, A

		MOV A, CZAS1-1
		ANL A, #00001111B
		MOV CZAS+3, A

		MOV A, CZAS1-1
		ANL A, #11110000B
		SWAP A
		MOV CZAS+2, A

		MOV A, CZAS1-2
		ANL A, #00001111B
		MOV CZAS+1, A

		MOV A, CZAS1-2
		ANL A, #11110000B
		SWAP A
		MOV CZAS, A
  	RET

WZORY:
	DB	00111111B, 00000110B, 01011011B, 01001111B	;0123
	DB	01100110B, 01101101B, 01111101B, 00000111B	;4567
	DB	01111111B, 01101111B, 01110111B, 01111100B	;89Ab
	DB	01011000B, 01011110B, 01111001B, 01110001B	;cdEF

END
