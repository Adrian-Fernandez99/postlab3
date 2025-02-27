/*

postlab3.asm

Created: 2/22/2025 12:15:08 PM
Author : Adrián Fernández

Descripción:
	Se realiza un contador binario de 4 bits
	que se presentan en cuatro leds externas.
	Se deben utilizar interrupciones de tipo
	On-change.
	Tiene que haber dos contadores externos
	que se controlan por medio del timer y 
	se muestran en un display de 7 segmentos.
	Uno sube cada segundo mientras el otro
	Cuando el primero llegue a 10.
*/
.include "M328PDEF.inc"		// Include definitions specific to ATMega328P

// Definiciones de registro, constantes y variables
.cseg
.org		0x0000			// Se dirigen el inicio
	JMP		START

.org		PCI0addr		// Se dirigen las interrupciones del pinchange
	JMP		BOTONES

.org		OVF0addr		// Se dirigen las interrupciones del timer
	JMP		OVERFLOW


TABLA7SEG: .DB	0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B, 0x77, 0x4F, 0x4E, 0x6D, 0x4F, 0x47
//				0,    1,    2,    3,    4,    5,    6,    7,    8,    9,    A,    B,    C,    D,    E,    F

// Configuración de la pila
START:
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

// Configuración del MCU
SETUP:
	// Desavilitamos interrupciones mientras seteamos todo
	CLI
	CALL	OVER

	// Configurar Prescaler "Principal"
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16		// Habilitar cambio de PRESCALER
	LDI		R16, 0x04
	STS		CLKPR, R16		// Configurar Prescaler a 16 F_cpu = 1MHz

	// Inicializar timer0
	CALL	INIT_TMR0

	// Deshabilitar serial (esto apaga los demas LEDs del Arduino)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	// Interrupciones de botones
	// Habilitamos interrupcionees para el PCIE0
	LDI		R16, (1 << PCINT1) | (1 << PCINT0)
	STS		PCMSK0, R16
	// Habilitamos interrupcionees para cualquier cambio logico
	LDI		R16, (1 << PCIE0)
	STS		PCICR, R16

	// Interrupciones del timer
	// Habilitamos interrupcionees para el timer
	LDI		R16, (1 << TOIE0)
	STS		TIMSK0, R16

	// PORTD como entrada con pull-up habilitado
	LDI		R16, 0x00
	OUT		DDRB, R16		// Setear puerto B como entrada
	LDI		R16, 0xFF
	OUT		PORTB, R16		// Habilitar pull-ups en puerto B

	// Configurar puerto C como una salida
	LDI		R16, 0xFF
	OUT		DDRC, R16		// Setear puerto C como salida

	// Configurar puerto D como una salida
	LDI		R16, 0xFF
	OUT		DDRD, R16		// Setear puerto D como salida

	// Realizar variables
	LDI		R16, 0x00		// Registro del contador
	LDI		R17, 0x00		// Registro de lectura de botones
	LDI		R18, 0x00		// Registro para el display
	LDI		R19, 0x00		// Registro de overflows de timer0
	LDI		R20, 0x00		// Registro del timer
	LDI		R21, 0x00		// Timer interrupcion
	LDI		R22, 0x00		// Registro para el segundo contador
	LDI		R23, 0x00		// Registro para el segundo display
	LDI		R24, 0x00		// Registro para decidir que display mostrar

	// Activamos las interrupciones
	SEI

// Main loop
MAIN_LOOP:
	SEI

	CPI		R24, 0x00
	BREQ	DISPLAY
	SBI		PORTC, 4		// Se setea el pin 4 del puerto
	CBI		PORTC, 5		// Se clearea el pin 5 del puerto C
	OUT		PORTD, R23		// Sale la señal del contador 1
	JMP		CONTINUAR

	DISPLAY:
	CBI		PORTC, 4		// Se clearea el pin 4 del puerto C
	SBI		PORTC, 5		// Se setea el pin 5 del puerto C
	OUT		PORTD, R18		// Sale la señal del contador 2

	CONTINUAR:
	OUT		PORTC, R16		// Se loopea la salida del puerto
	
	CPI		R19, 200		// Se esperan 200 overflows para hacer un segundo
	BRNE	MAIN_LOOP		

	CLR		R19				// Se limpia el registro de R19
	CALL	SUMA			// Se llama el incremento del dislpay
	JMP		MAIN_LOOP

// NON-Interrupt subroutines
INIT_TMR0:
	LDI		R16, (1 << CS00) | (1 << CS01) | (0 << CS02)
	OUT		TCCR0B, R16		// Setear prescaler del TIMER 0 a 64
	LDI		R16, 178
	OUT		TCNT0, R16		// Cargar valor inicial en TCNT0
	RET

SUMA:						// Función para el incremento del primer contador
	INC		R20				// Se incrementa el valor
	CPI		R20, 10
	BRNE	SALTITO			// Se observa si tiene más de 4 bits
	LDI		R20, 0x00		// En caso de overflow y debe regresar a 0
	CALL	SUMA2
	SALTITO:
	CALL	OVER			// Se resetea el puntero
	ADD		ZL, R20			// Se ingresa el registro del contador al puntero
	LPM		R18, Z			// Subir valor del puntero a registro
	RET

SUMA2:
	INC		R22				// Se incrementa el valor
	CPI		R22, 6
	BRNE	SALTITO2		// Se observa si tiene más de 4 bits
	LDI		R22, 0x00		// En caso de overflow y debe regresar a 0
	SALTITO2:
	CALL	OVER			// Se resetea el puntero
	ADD		ZL, R22			// Se ingresa el registro del contador al puntero
	LPM		R23, Z			// Subir valor del puntero a registro
	RET

OVER:
	LDI		ZL, LOW(TABLA7SEG << 1)				// Ingresa a Z los registros de la tabla más bajos
	LDI		ZH, HIGH(TABLA7SEG << 1)			
	RET

// Interrupt routines
BOTONES:
	CLI						// Deshabilitamos las interrupciones

	PUSH	R18				// Se guarda el registro actual de R18
    IN		R18, SREG		// Se ingresa el registro del SREG a R18
    PUSH	R18				// Se guarda el registro del SREG

	IN		R17, PINB		// Se ingresa la configuración del PIND
	CPI		R17, 0x1D		// Se compara para ver si el botón está presionado
	BRNE	DECREMENTO		// Si no esta preionado termina la interrupción
	INC		R16				// Si está presionado incrementa
	SBRC	R16, 4			// Si genera overflow reinicia contador
	LDI		R16, 0x00
	JMP		FINAL			// Regreso de la interrupción
	DECREMENTO:
	CPI		R17, 0x1E		// Se compara para ver si el botón está presionado
	BRNE	FINAL			// Si no esta preionado termina la interrupción
	DEC		R16				// Si está presionado decrementa
	SBRC	R16, 4			// Si genera underflow reinicia contador
	LDI		R16, 0x0F
	FINAL: 

	POP		R18				// Se trae el registro del SREG
    OUT		SREG, R18		// Se ingresa el registro del SREG a R18
    POP		R18				// Se trae el registro anterior de R18	

	RETI					// Regreso de la interrupción

OVERFLOW:
	CLI

	PUSH	R17				// Se guarda el registro actual de R18
    IN		R17, SREG		// Se ingresa el registro del SREG a R18
    PUSH	R17				// Se guarda el registro del SREG

	CPI		R24, 0x00
	BREQ	DISPLAY2
	LDI		R24, 0x00
	JMP		CONTINUAR2

	DISPLAY2:
	LDI		R24, 0x01

	CONTINUAR2:

	LDI		R17, 178
	OUT		TCNT0, R17		// Cargar valor inicial en TCNT0
	INC		R19				// Se incrementa el tiempo del timer

	POP		R17				// Se trae el registro del SREG
    OUT		SREG, R17		// Se ingresa el registro del SREG a R18
    POP		R17				// Se trae el registro anterior de R18	

	RETI
