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

	// Activamos las interrupciones
	SEI

// Main loop
MAIN_LOOP:
	SEI
	OUT		PORTC, R16		// Se loopea la salida del puerto
	CPI		R19, 50			// Se esperan 50 overflows para hacer un segundo
	BRNE	MAIN_LOOP
	CLR		R19
	CALL	SUMA
	OUT		PORTD, R18		// Sale la señal
	JMP		MAIN_LOOP

// NON-Interrupt subroutines
INIT_TMR0:
	LDI		R16, (0 << CS00) | (0 << CS01) | (1 << CS02)
	OUT		TCCR0B, R16		// Setear prescaler del TIMER 0 a 256
	LDI		R16, 178
	OUT		TCNT0, R16		// Cargar valor inicial en TCNT0
	RET

SUMA:						// Función para el incremento del primer contador
	INC		R20				// Se incrementa el valor
	ADIW	Z, 1			// Se incrementa el valor en el puntero de la tabla
	CPI		R20, 10
	BRNE	SALTITO			// Se observa si tiene más de 4 bits
	CALL	OVER			// En caso de overflow y debe regresar el puntero a 0
	LDI		R20, 0x00		// En caso de overflow y debe regresar a 0
	SALTITO:
	LPM		R18, Z			// Subir valor del puntero a registro
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

	PUSH	R18				// Se guarda el registro actual de R18
    IN		R18, SREG		// Se ingresa el registro del SREG a R18
    PUSH	R18				// Se guarda el registro del SREG

	LDI		R16, 178
	OUT		TCNT0, R16		// Cargar valor inicial en TCNT0
	INC		R19				// Se incrementa el tiempo del timer

	POP		R18				// Se trae el registro del SREG
    OUT		SREG, R18		// Se ingresa el registro del SREG a R18
    POP		R18				// Se trae el registro anterior de R18	

	RETI
