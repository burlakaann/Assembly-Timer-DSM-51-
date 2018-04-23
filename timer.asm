

CSDS16	EQU	0FF30H	;adres zatrzasku wyboru wska�nika/wy�wietlacza
CSDB16	EQU	0FF38H	;adres zatrzasku wyboru segment�w/wzork�w

SEGOFF	BIT	P1.6	;ten bit w��cza wy�wietlacze

CZAS  EQU 7AH
CZAS1 EQU 79H
LICZNIK EQU 75H
LICZNIK1 EQU 74H

LDTEST	EQU	P1.7	;w��cza (0) / wy��cza (1) diod� TEST
SEQKEY	EQU	P3.5	;testuje naci�ni�cie (1) klawisza KSQ

KeyCount	EQU	73H	;zlicza powt�rzenia klawisza
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

	LJMP	TI0MAIN	;w ten spos�b omijamy ograniczenie do 8 bajt�w
;=======================================
;	TIMER 0 INTERRUPT MAIN
	ORG	0B0H			;od B0h do 100h jest 80 bajt�w, na pewno wystarczy

TI0MAIN:
	PUSH	ACC			;zabezpieczamy wykorzystywane rejestry
	PUSH	PSW			;

	MOV	TH0, #255 - 3	;warto�� typowa

	MOV	A, #256 - 154 + 1	; + 1 aby nadrobi� strat�
	ADD	A, TL0		;uwzgl�dnia op�nienie wywo�ania przerwania
	MOV	TL0, A		;TL0 ustawione w�a�ciwie

	JNC	TI0MAIN_TH0_OK	;je�eli nie Carry to jest OK
	INC	TH0			;wpr podbijamy TH0 w stosuku do warto�ci typowej

TI0MAIN_TH0_OK:			;TH0 ustawione w�a�ciwie
	POP	PSW			;odzyskujemy wykorzystywane rejestry
	POP	ACC			;

	SETB	T0IB			;informujemy p�tl� g��wn� o przerwaniu

	RETI				;powr�t z przerwania

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

      MOV	IE,	#00h	;blokada wszystkich przerwa�

		MOV	TMOD,	#71h	;T1.GATE=0 T1.C/T=C T1.MODE=3 T0.GATE=0 T1.C/T=T T0.MODE=1
		MOV	TCON,	#10h	;m.in. blokada zliczania przez T1, aktywuje zliczanie przez timer 0
		SETB	ET0		;aktywuje przerwanie od timer 0
		SETB	EA		;globalne zezwolenie na obs�ug� przerwa�



;adres zatrzasku wyboru wska�nik�w do DPTR
;na razie zmienia si� niewiele, przenosimy funkcje kontrolne do rejestr�w R6 i R7
;�eby zwolni� akumulator do innch zada�,
;w dalszym ci�gu ten sam wzorek na wszystkich wy�wietlaczach

LoopIni:
	MOV	R0, #CZAS		;zaczynamy od najm�odszego wy�wietlacza
						;R0 przyjmuje warto�ci 1, 2, 3, 4, 5, 6, 7
	MOV	R6, #32			;to jest najm�odszy wy�wietlacz bitowo
	MOV AgrKey, #00H						;R6 przyjmuje warto�ci 1, 2, 4, 8, 16, 32, 64

LoopRun:
	;DJNZ R4, LoopRun
	

        JNB	T0IB, LoopRun	;czeka na przerwanie
        CLR	T0IB		;zapomina �e by�o przerwanie

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



	MOV	A, @R0			;maska bitowa wybieraj�ca wy�wietlacz do A
        
        MOV	DPTR, #WZORY	;adres wzork�w do DPTR
	MOVC	A, @A+DPTR	;wzorek do A

	CJNE R0, #CZAS+1, Bez_kropkiH
	ORL A, #10000000b
Bez_kropkiH:

	CJNE R0, #CZAS+3, Bez_kropkiM
	ORL A, #10000000b
Bez_kropkiM:

	MOV	DPTR, #CSDB16	;adres zatrzasku wzork�w do DPTR
	SETB	SEGOFF
	MOVX	@DPTR, A	;wzorek do zatrzasku

	MOV	DPTR, #CSDS16

	MOV	A, R6			;maska bitowa wybieraj�ca wy�wietlacz do A
	MOVX	@DPTR, A	;wybierz wska�nik
        CLR SEGOFF
        JNB	SEQKEY, LoopRunNoKey	;je�eli klawisz odpowiadaj�cy masce w R6
						;nie jest naci�ni�ty

	ORL	AgrKey, A		;agreguj bit naci�ni�tego klawisza do AgrKey

LoopRunNoKey:



	RR	A				;w nast�pnym obrocie p�tli wybierz nast�pny,
	MOV	R6, A			;starszy wy�wietlacz - i zapami�taj to w R6

	INC	R0				;przestaw wska�nik na starszy wy�wietlacz
	CJNE	R0, #CZAS+6, LoopRun	;"8" w R0 oznacza mini�cie diod F1-ER

        MOV	A, AgrKey		;po obiegni�ciu wszystkich wy�wietlaczy/klawiszy
					;sprawdzamy stan klawiatury

	JZ	LoopRunNewKey	;je�eli nic nie jest naci�ni�te

LoopRunKey:
	CJNE	A, PrvKey, LoopRunNewKey	;je�eli stan klawiatury si� zmieni�

	MOV	A, KeyCount		;je�eli licznik powt�rze� ma warto�� 0 to znaczy
	JZ	LoopIni		;�e klawisz ju� wcze�niej zosta� zauwa�ony i obs�u�ony

	DJNZ	KeyCount, LoopIni	;klawiatura mo�e jeszcze nie by� ustabilizowana
					;wi�c ponownie zacznij od najm�odszego wy�wietlacza

					;licznik powt�rze� akurat osi�gn�� warto�� 0
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

			;tutaj mo�na regularnie obs�u�y� klawiatur�, w tym programie
					;ogranicza si� to wy��cznie do odwr�cenia stanu diody TEST
NoEsc:


        LJMP	LoopIni		;ponownie zacznij od najm�odszego wy�wietlacza

LoopRunNewKey:
	MOV	KeyCount, #25	;odnawiamy licznik powt�rze�
	MOV	PrvKey, AgrKey	;zapami�tuje "poprzedni" stan klawiatury
	LJMP	LoopIni		;ponownie zacznij od najm�odszego wy�wietlacza


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
