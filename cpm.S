	.file	"cpm.S"
	.machinemode zarch
	.machine "z13"

	.include	"system.def"
	
	.text
	.align	8
	.global main
	.type	main, @function
	
    .equ    NUMBER_OF_DIR_ENTRIES, 128  // = 2 blocs
    .equ    NUMBER_OF_DATA_BLOCKS, 398  // = 400 - les 2 du répertoire
    .equ    BLOCK_SIZE, 2048            // unité d'allocation indivisible
    .equ    DIRECTORY_SIZE, 32

main:
	STMG	R6, R15, 48(R15)	    // save registers into caller's save area
	LAY		R15, -160(R15)          // set new stack pointer
	LARL	R2, COMMANDE
    BRASL   R14, printf@PLT         // afficher la commande
    LGRL    R0, FIRST_GETCHAR       // premier appel de getchar ?
    LTGR	R0, R0
    JNZ		GETCHAR                 // non
M1:
    BRASL	R14, getchar@PLT        // empty input buffer
    CLGFI	R2, 0x0A
    JNE		M1
GETCHAR:
	LGFI	R0, 0                   
    STGRL 	R0, FIRST_GETCHAR       // clear first getchar
    BRASL	R14, getchar@PLT        // get 1 char from keyboard
    CLGFI	R2, 0x0A                // si commande vide, alors nouvelle lecture
    JE      GETCHAR
    CLGFI	R2, 0x31                // 1?
    JNE     M10                     // si non
    BRAS    R14, FORMAT_DISK
    J       M90                     // jump to end
    
M10:
    CLGFI	R2, 0x32                // 2?
    JNE     M20
    BRAS	R14, READ_DIRECTORY
    J       M90
    
M20:
    CLGFI   R2, 0x33
    JNE     M90
// export
    LARL    R2, COMMANDE2
    BRASL   R14, printf@PLT
    LARL    R6, FILE_TO_FETCH
    LARL    R7, FILE_TO_FETCH2
    LARL    R2, SPACES11
    XGR     R0, R0
    MVST    R7, R2
    LARL    R7, FILE_TO_FETCH2
    LGFI    R1, 12              // nombre de caractères maximum à acquérir
M31:
    BRASL   R14, getchar@PLT    // empty input buffer
    CLGFI   R2, 0x0A
    JNE     M31
GETCHAR2:
    BRASL   R14, getchar@PLT
    BRASL   R14, toupper@PLT
    STC     R2, 0(R6)
    STC     R2, 0(R7)
    ALGFI   R6, 1
    ALGFI   R7, 1
    SLGFI   R1, 1
    CFI     R2, 0x2E            // point
    JE      DOT
    CFI     R2, 0x0A            // new line
    JE      END1
    LTGR    R1, R1
    JZ      END2                // max 12 characters (FFFFFFFF.TTT)
    J       GETCHAR2
    
DOT:
    LGFI    R1, 0x20            // space
    SLGFI   R7, 1
    STC     R1, 0(R7)
    LARL    R7, FILE_TO_FETCH2
    ALGFI   R7, 8               // first char of filetype
    J       GETCHAR2
    
END1:
    LGFI    R1, 0x20            // space
    SLGFI   R7, 1
    STC     R1, 0(R7)
    XGR     R1, R1
    SLGFI   R6, 1
    STC     R1, 0(R6)          // replace 0x0a by 0x00
END2:
    LARL    R2, debug1
    LARL    R3, FILE_TO_FETCH
    LARL    R4, FILE_TO_FETCH2
    BRASL   R14, printf@PLT
    BRAS    R14, FETCH_FILE
M90:
    J       main

//  BRASL   R14, fcloseall@PLT
	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14
 	
CREATE_DISK_IMAGE:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LARL    R2, DISK_IMAGE
    LARL    R3, CREATE_OPTION
    BRASL   R14, fopen@PLT
    STGRL   R2, FID_CPM
    LTGR    R2, R2
    JNZ     CDI
    LARL    R2, MSG3
    LARL    R3, DISK_IMAGE
    J       ABEND

CDI:
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14
	
WRITE_DISK_IMAGE:               // in : R2 = address of buffer, R3 = element length, R4 = number of elements
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LGRL    R5, FID_CPM
    LGR     R6, R4
    BRASL   R14, fwrite@PLT
    CGR     R2, R6              // number of elements written
    JE      WDI
    LARL    R2, MSG4
    LARL    R3, DISK_IMAGE
    J       ABEND
    
WDI:
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14

CLOSE_DISK_IMAGE:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LGRL    R2, FID_CPM         // file pointer
    BRASL   R14, fclose@PLT
    LTGR    R2, R2
    JZ      LDI
    LARL    R2, MSG5
    LARL    R3, DISK_IMAGE
    J       ABEND
    
LDI:
    XGR     R0, R0
    STGRL   R0, FID_CPM
    LAY		R15, 160(R15)
    LMG		R6, R15, 48(R15)
    BR		R14

FORMAT_DISK:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    BRAS    R14, CREATE_DISK_IMAGE
// write directory entries
// dans CP/M toute la zone des répertoires est remplie de E5, mais je préfère écrire une trame de répertoire à la place
// t = fwrite ( str, len, 1, fp);
    LGFI    R6, NUMBER_OF_DIR_ENTRIES
FD1:
    LARL    R2, DIRECTORY              // string to write
    LGFI    R3, DIRECTORY_SIZE          // element length
    LGFI    R4, 1                       // number of elements
    BRAS    R14, WRITE_DISK_IMAGE
    BRCTG   R6, FD1
// initialize data blocks (comme dans CP/M)
    LGFI    R6, NUMBER_OF_DATA_BLOCKS
FD2:
    LARL    R2, E5
    LGFI    R3, BLOCK_SIZE
    LGFI    R4, 1
    BRAS    R14, WRITE_DISK_IMAGE
    BRCTG   R6, FD2
    BRAS    R14, CLOSE_DISK_IMAGE
    LARL    R2, FORMAT_DONE
    BRASL   R14, printf@PLT
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
    BR      R14

OPEN_DISK_IMAGE:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LGRL    R2, FID_CPM
    LTGR    R2, R2
    JNZ     ODI_DEJA_OUVERTE            // si différent de 0 alors déjà ouvert
    LARL    R2, DISK_IMAGE
    LARL    R3, READ_OPTION
    BRASL   R14, fopen@PLT
    LTGR    R2, R2
    JNZ     ODI                         // problème
    LARL    R2, MSG2
    LARL    R3, DISK_IMAGE
    J       ABEND

ODI_DEJA_OUVERTE:
    LARL    R2, MSG11
    BRASL   R14, printf@PLT
    J       ODI_END
    
ODI:
    STGRL   R2, FID_CPM
    LARL    R2, MSG10
    BRASL   R14, printf@PLT
ODI_END:
    LAY		R15, 160(R15)
    LMG		R6, R15, 48(R15)
    BR		R14
    
READ_DISK_IMAGE:                // in : R2 = address of buffer, R3 = element length, R4 = number of elements
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LGRL    R5, FID_CPM
    LGR     R7, R3
    LGR     R6, R4
    BRASL   R14, fread@PLT
    CGR     R2, R6              // number of elements read
    JE      RDI
    LARL    R2, MSG6
    LARL    R3, DISK_IMAGE
    J       ABEND
    
RDI:
    LARL    R2, MSG12
    LGR     R3, R7
    BRASL   R14, printf@PLT
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14
 	
POSITION_DISK_IMAGE:            // in : R3 = offset depuis le début du fichier
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	LGR     R9, R3
    LGRL    R2, FID_CPM         // file pointer
    LGFI    R4, 0               // SEEK_SET = 0, SEEK_CUR = 1, SEEK_END = 2
    BRASL   R14, fseek@PLT
    LTGR    R2, R2
    JZ      PDI
    LARL    R2, MSG7
    LARL    R3, DISK_IMAGE
    J       ABEND
    
PDI:
    LARL    R2, MSG13
    LGR     R3, R9
    BRASL   R14, printf@PLT
    LAY		R15, 160(R15)
    LMG		R6, R15, 48(R15)
    BR		R14
	 
/* La FAT est une bitmap, c'est-à-dire 1 bit par bloc (unité d'allocation).
 * Pour simplifier : je suppose que toutes les entrées de répertoire d'un même fichier se suivent
 *  et qu'il n'y a pas une autre qui traine plus loin, ce qui pourrait arriver si la disquette a déjà beaucoup travaillé */
 
READ_DIRECTORY:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    BRAS    R14, OPEN_DISK_IMAGE
    XGR     R3, R3              // remettre au début du fichier
    BRAS    R14, POSITION_DISK_IMAGE
    LARL    R2, DIR_BUFFER
    LGFI    R3, DIRECTORY_SIZE*NUMBER_OF_DIR_ENTRIES
    LGFI    R4, 1
    BRAS    R14, READ_DISK_IMAGE
// all directories are now read
// on va recenser tous les blocs alloués et renseigner la bitmap
	LARL    R2, REPERTOIRE
	BRASL   R14, printf@PLT
    XGR     R0, R0
    STGRL   R0, BLOCK_COUNTER           // allocated blocks counter
    STGRL   R0, SECTOR_COUNTER          // sectors counter
    LARL    R6, DIR_BUFFER
    LGFI    R7, NUMBER_OF_DIR_ENTRIES
LOOP2:
    IC      R0, 0(R6)
    CLGFI   R0, 0xE5
    JE      .CONTINUE           // unused dir entry
// afficher nom et taille
    IC      R0, 12(R6)
    LTGR    R0, R0
    JH      .NOT_FIRST_ENTRY
    LGFI    R9, 8               // filename FFFFFFFF
    LGFI    R8, 1               // 1er caractère du nom
LOOP21:
    XGR     R2, R2
    IC      R2, 0(R8, R6)
    ALGFI   R8, 1
    CLGFI   R2, 0x20            // espace
    JE      .SKIP1
    BRASL   R14, putchar@PLT
.SKIP1: 
    BRCTG   R9, LOOP21
    LGFI    R2, 0x2E            // point
    BRASL   R14, putchar@PLT
    LGFI    R8, 9
    LGFI    R9, 3               // type TTT
LOOP22:
    IC      R2, 0(R8, R6)
    ALGFI   R8, 1
    CLGFI   R2, 0x20
    JE      .SKIP2
    BRASL   R14, putchar@PLT
.SKIP2:
    BRCTG   R9, LOOP22
    LGFI    R2, 0x20            // space
    BRASL   R14, putchar@PLT
    XGR     R0, R0
    STGRL   R0, FILESIZE
.NOT_FIRST_ENTRY:
    IC      R0, DIRECTORY_SIZE(R6)
    CLGFI   R0, 0xE5
    JE      .LAST_ENTRY         // si l'entrée suivante n'est pas valide
    IC      R0, DIRECTORY_SIZE+12(R6)
    LTGR    R0, R0
    JZ      .LAST_ENTRY         // si Xt de l'entrée suivante = 0
    IC      R0, 15(R6)          // number of sectors
    LGRL    R1, FILESIZE
    ALGR    R1, R0
    STGRL   R1, FILESIZE
    LGRL    R1, SECTOR_COUNTER
    ALGR    R1, R0
    STGRL   R1, SECTOR_COUNTER
    J       .FILL_FAT
    
.LAST_ENTRY:
    IC      R0, 15(R6)          // number of sectors
    LGRL    R1, FILESIZE
    ALGR    R1, R0
    STGRL   R1, FILESIZE
    LGRL    R1, SECTOR_COUNTER
    ALGR    R1, R0
    STGRL   R1, SECTOR_COUNTER
    LARL    R2, TAILLE
    LGRL    R3, FILESIZE
    BRASL   R14, printf@PLT
// renseigner la FAT
.FILL_FAT:
    LARL    R10, FAT
    LGFI    R8, 16
.LOOP3:
    XGR     R0, R0
    LRVH    R0, 0(R8, R6)        // change endianess
    LTGR    R0, R0
    JZ      .RIEN_A_FAIRE
// the FAT is a bitmap : divide D5 by 8 gives the byte address and the remainder (modulo 8) the bit to set
// en version ARM, je vais le faire avec des AND et LSR
    LGR     R1, R0
    NILL    R1, 7               // = le reste de la division
    SRLG    R2, R0, 3           // = le quotient ; 3 signifie 3(R0)
    LGFI    R0, 1
    SLL     R0, 0(R1)           // masque
    XGR     R3, R3
    IC      R3, 0(R2, R10)
    OGR     R3, R0
    STC     R3, 0(R2, R10)
    LGRL    R1, BLOCK_COUNTER
    ALGFI   R1, 1
    STGRL   R1, BLOCK_COUNTER
.RIEN_A_FAIRE:
    LGFI    R0, 2
    LGFI    R1, 30
    BRXLG   R8, R0, .LOOP3
.CONTINUE:
    ALGFI   R6, DIRECTORY_SIZE
    BRCTG   R7, LOOP2
// affichage de l'espace occupé
    LARL    R2, TOTAL_BLOCKS
    LGRL    R3, BLOCK_COUNTER
    BRASL   R14, printf@PLT
    LARL    R2, TOTAL_SECTORS
    LGRL    R3, SECTOR_COUNTER
    BRASL   R14, printf@PLT
RD:	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
	BR      R14

CREATE_OUTPUT_FILE:         // in : R2 = address of filename - out : R2 = 0 if success
    STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LARL    R3, CREATE_OPTION
    BRASL   R14, fopen@PLT
    STGRL   R2, FID_EXP
    LTGR    R2, R2
    JNZ     COF
    LARL    R2, MSG1
    LARL    R3, FILE_TO_FETCH
    J       ABEND

COF:
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14
	

WRITE_OUTPUT_FILE:              // in : R3 = size
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    LARL    R2, BLOCK_BUFFER
    LGFI    R4, 1               // 1 element to write
    LGRL    R5, FID_EXP
    LGR     R6, R4
    BRASL   R14, fwrite@PLT
    CGR     R2, R6              // number of elements written
    JE      WOF
    LARL    R2, MSG8
    LARL    R3, FILE_TO_FETCH
    J       ABEND

WOF:
 	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
 	BR		R14	

CLOSE_OUTPUT_FILE:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	LGRL    R2, FID_EXP
    BRASL   R14, fclose@PLT
    LTGR    R2, R2
    JZ      LOF
    LARL    R2, MSG9
    LARL    R3, FILE_TO_FETCH
    J       ABEND

LOF:
    LAY		R15, 160(R15)
    LMG		R6, R15, 48(R15)
    BR		R14

EXPORT_BLOCK:               // in : R2 = numéro de bloc à exporter (on démarre à 2, après le répertoire)
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	LGR     R9, R2
	LARL    R2, BLOCK_NUMBER
	LGR     R3, R9
	BRASL   R14, printf@PLT
	LGFI    R2, 0
	LGFI    R3, BLOCK_SIZE
	LGR     R4, R9          // multiplicateur
	MLGR    R2, R4          // R3 = poids faible du résultat
	BRAS    R14, POSITION_DISK_IMAGE
    LARL    R2, BLOCK_BUFFER
    LGFI    R3, BLOCK_SIZE
    LGFI    R4, 1
    BRAS    R14, READ_DISK_IMAGE
    LGRL    R5, NUM_SECTORS_READ
    LGFI    R6, 16
    AGRK    R5, R5, R6
    STGRL   R5, NUM_SECTORS_READ    // nombre de secteurs lus + 16 (16x128=2048)
// write block to output (export) file
    XGR     R0, R0
    STGRL   R0, STOP
    LGFI    R3, BLOCK_SIZE
    LGRL    R4, NUM_SECTORS_READ
    LGRL    R5, NUM_SECT_TO_READ
    CLGR    R4, R5
    JNH     .WRITE_ALL              // not too much read
// de combien de secteurs faut-il raccourcir ?
    LGFI    R0, 1
    STGRL   R0, STOP
    SLGR    R4, R5                  //  SUB  W0, NUM_SECTORS_READ, NUM_SECT_TO_READ -- R4 = nombre de secteurs à tronquer
    LGFI    R2, 0
	LGFI    R3, 128
//	LGR     R4, R4          // multiplicateur
	MLGR    R2, R4          // R3 = poids faible du résultat ; nombre d'octets à retrancher
    LGFI    R0, BLOCK_SIZE
    SLGRK   R3, R0, R3      // R3 = block_size - (128*nb de sect à enlever)
// recherche du ctrl-Z
    LARL    R5, BLOCK_BUFFER
    LGFI    R1, 1
    XGR     R0, R0
.EB1:
    SLGRK   R6, R3, R1      // pointe au départ sur le dernier octets
    IC      R0, 0(R6, R5)
    CLGFI   R0, 0x1A        // control Z
    JNE     .WRITE_ALL
    SLGFI   R3, 1
    J       .EB1
    
.WRITE_ALL:
    BRAS    R14, WRITE_OUTPUT_FILE   // R3 = nombre d'octets à écrire
    LAY		R15, 160(R15)
    LMG		R6, R15, 48(R15)
    BR		R14
	
FETCH_FILE:
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
    XGR     R0, R0
    STGRL   R0, NUM_SECT_TO_READ
    STGRL   R0, NUM_SECTORS_READ
    LARL    R2, FILE_TO_FETCH
    BRAS    R14, CREATE_OUTPUT_FILE
    BRAS    R14, READ_DIRECTORY
	LARL    R6, DIR_BUFFER
	LGFI    R7, 1                  // R7 = ENTRY_NUMBER, from 1 to number of dir entries
LOOP1:
    XGR     R9, R9
    LARL    R8, FILE_TO_FETCH2
    XGR     R0, R0
    IC      R0, 0(R9, R6)
    CLGFI   R0, 0xE5               // entrée libre ?
    JE      RIEN_A_FAIRE
LOOP2F:
    CLC     1(11, R6), 0(R8)
    JO      LOOP2F
	JE      TROUVE
    J       RIEN_A_FAIRE
// file found, get block numbers
TROUVE:
    LGFI    R11, 8          // 8 block numbers
    ALGFI   R9, 15          // pointe vers la taille (nombre de secteurs)
    XGR     R0, R0
    IC      R0, 0(R9, R6)
    LGRL    R1, NUM_SECT_TO_READ
    ALGR    R1, R0
    STGRL   R1, NUM_SECT_TO_READ    
    ALGFI   R9, 1           // pointe vers le 1er Al
LOOP3:
    XGR     R0, R0
    LRVH    R0, 0(R9, R6)        // change endianess
    LTGR    R0, R0
    JZ      NOT_ALLOCATED
    LGR     R2, R0
    BRAS    R14, EXPORT_BLOCK
    LGRL    R0, STOP
    LTGR    R0, R0
    JNZ     EXIT
NOT_ALLOCATED:
    ALGFI   R9, 2
    BRCTG   R11, LOOP3
RIEN_A_FAIRE:
    LGFI    R2, 1
    LGFI    R3, NUMBER_OF_DIR_ENTRIES
    BRXHG   R7, R2, EXIT
    ALGFI   R6, DIRECTORY_SIZE      // pointer vers l'entrée suivante
    J       LOOP1

EXIT:
    BRAS    R14, CLOSE_OUTPUT_FILE
    LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
    BR      R14
    
ABEND:
    BRASL   R14, printf@PLT
    LGFI    R2, 1           // code retour
    SVC     SYS_EXIT

	.section	.rodata
	.align	8
DISK_IMAGE:     .asciz  "cpmdisk.bin"
	.align	8
MSG1:           .asciz  "Erreur de création du fichier de sortie '%s'.\n"
	.align	8
MSG2:           .asciz  "Erreur de lecture de l'image de disquette '%s'.\n"
	.align	8
MSG3:           .asciz  "Erreur de création de l'image de disquette '%s'\n"
	.align	8
MSG4:           .asciz  "Erreur d'écriture de l'image de disquette '%s'\n"
	.align	8
MSG5:           .asciz  "Erreur de fermeture de l'image de disquette '%s'\n"
	.align	8
MSG6:           .asciz  "Erreur de lecture de l'image de disquette '%s'\n"
	.align	8
MSG7:           .asciz  "Erreur de positionnement de l'image de disquette '%s'\n"
	.align	8
MSG8:           .asciz  "Erreur d'écriture du fichier exporté '%s'\n"
	.align	8
MSG9:           .asciz  "Erreur de fermeture du fichier exporté '%s'\n"
    .align  8
MSG10:          .asciz  "    Disquette CP/M ouverte maintenant.\n"
    .align  8
MSG11:          .asciz  "    Disquette CP/M ouverte précédemment.\n"
    .align  8
MSG12:          .asciz  "    Disquette CP/M : nombre octets lus %d.\n"
    .align  8
MSG13:          .asciz  "    Disquette CP/M positionnée à %d.\n"
	.align	8
FORMAT_DONE:    .asciz  "Formatage effectué\n"
	.align	8
COMMANDE:       .asciz  "Commande ? 1=format, 2=dir, 3=export file : "
	.align	8
COMMANDE2:      .asciz  "Nom du fichier à exporter : "
	.align	8
REPERTOIRE:     .asciz  "\nRépertoire de la disquette CP/M :\n\n"
	.align	8
TAILLE:         .asciz  " %d secteurs (de 128 octets)\n"
	.align	8
TOTAL_BLOCKS:   .asciz  "Nombre de blocs alloués %d sur 498\n"
	.align	8
TOTAL_SECTORS:  .asciz  "Nombre de secteurs alloués %d sur 6368\n\n"
    .align  8
BLOCK_NUMBER:   .asciz  "    Buméro de bloc exporté : %d\n"
	.align	8
CREATE_OPTION:  .asciz  "w+"
	.align	8
READ_OPTION:    .asciz  "r+"
	.align	8
SPACES11:       .asciz  "           "

// directory entry
// inspired by CP/M which is little endian
// Us Fn Fn Fn Fn Fn Fn Fn Fn Ty Ty Ty Xt At Lh Ll
// Al Al Al Al Al Al Al Al Al Al Al Al Al Al Al Al
DIRECTORY:  .byte   0xE5            // user number
FILENAME:   .space  8, 0x46         // file name
FILETYPE:   .space  3, 0x54         // file type
EXTEND:     .byte   0               // extend number (0 = no extend, 1 = extend n° 1...)
ATTRIBUTES: .byte   0               // attributes (saved, public, protected...)
TIMESTAMP:  .byte   0
FILELENGTH: .byte   0               // file length in sectors of 128 bytes
ALLOCATION: .space  16              // $0,$0,$0,$0,$0,$0,$0,$0  blocks allocated to the file, Al

	.data
	.align 8	
FILE_TO_FETCH:
    .asciz  "FFFFFFFF.TTT"
    .align  8
FILE_TO_FETCH2:
    .asciz  "FFFFFFFFTTT?"
	.align	8
FID_CPM:        .quad   0
FID_EXP:        .quad   0
FIRST_GETCHAR:  .quad   1
BLOCK_COUNTER:  .quad   0
SECTOR_COUNTER: .quad   0
FILESIZE:       .quad   0
NUM_SECT_TO_READ:
    .quad   0
NUM_SECTORS_READ:
    .quad   0
ENTRY_NUMBER:
    .quad   0
STOP:
    .quad   0

// initialized buffers
E5: .space  BLOCK_SIZE, 0xE5

// debug messages
	.align	8
debug1:
    .asciz  "File to fetch '%s', file to fetch2 '%s'\n"
	
	.bss

	.align	8
FAT:            .space  NUMBER_OF_DATA_BLOCKS/8+1
	.align	8
DIR_BUFFER:     .space  DIRECTORY_SIZE*NUMBER_OF_DIR_ENTRIES
	.align	8
BLOCK_BUFFER:   .space  BLOCK_SIZE

	.section	.note.GNU-stack,"",@progbits

	.end
