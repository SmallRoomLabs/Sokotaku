/*
 *   ______       _                     _           
 *  / _____)     | |          _        | |          
 * ( (____   ___ | |  _ ___ _| |_ _____| |  _ _   _ 
 *  \____ \ / _ \| |_/ ) _ (_   _|____ | |_/ ) | | |
 *  _____) ) |_| |  _ ( |_| || |_/ ___ |  _ (| |_| |
 * (______/ \___/|_| \_)___/  \__)_____|_| \_)____/ 
 *
 * v1.0 Created November 2010 by Mats Engstrom <mats@smallroomlabs.com>
 *
 * This software is licensed under the Creative Commons Attribution-
 * ShareAlike 3.0 Unported License.
 * http://creativecommons.org/licenses/by-sa/3.0/
 * 
 */


#include <avr/pgmspace.h>
#include "Rainbow.h"
#include "data.h"

#define BUTTON_UP	1
#define BUTTON_DOWN	2
#define BUTTON_LEFT 	4
#define	BUTTON_RIGHT	8

#define MAP_EMPTY   0
#define MAP_GOAL    1
#define MAP_BOX     2
#define MAP_WALL    4

#define NOTINUSE    0xFF
#define NOMORE      0

#define MAXLRUD    50
#define LEVELSIZE  21
#define NRBOXES     6
#define NRGOALS     6
#define ROWS        8
#define COLS        8

#define SCROLLSPEED 90
#define FLASHRATE  0x10

#define COLOR_GOAL       0xF00  // Red
#define COLOR_BOX        0xFF0  // Yellow
#define COLOR_WALL       0x111  // White
#define COLOR_SOLVED     0x0F0  // Green
#define COLOR_PLAYER     0x00F  // Blue
#define COLOR_BACKGROUND 0x000  // Black



unsigned char dots_color[2][3][8][4];  //define Two Buffs (one for Display ,the other for receive data)

unsigned char GamaTab[16]=
	{0xFF,0xFE,0xFD,0xFC,0xFB,0xF9,0xF7,0xF5,0xF3,0xF0,0xED,0xEA,0xE7,0xE4,0xE1,0xDD};  // Progressive gamma

PROGMEM prog_uchar sokomapData[]  = {
#include "levels.h"
};



unsigned char line,level;
byte surface=0;
byte  sokomap[ROWS][COLS];
byte  playerX, playerY;
byte  lrud[MAXLRUD];
byte  moves;
byte  pushes;




ISR(TIMER2_OVF_vect)          //Timer2  Service 
{ 
  TCNT2 = GamaTab[level];    // Reset a  scanning time by gamma value table
  flash_next_line(line,level);  // sacan the next line in LED matrix level by level.
  line++;
  if(line>7)        // when have scaned all LEC the back to line 0 and add the level
  {
    line=0;
    level++;
    if(level>15)       level=0;
  }
}

void init_timer2(void)               
{
  TCCR2A |= (1 << WGM21) | (1 << WGM20);   
  TCCR2B |= (1<<CS22);   // by clk/64
  TCCR2B &= ~((1<<CS21) | (1<<CS20));   // by clk/64
  TCCR2B &= ~((1<<WGM21) | (1<<WGM20));   // Use normal mode
  ASSR |= (0<<AS2);       // Use internal clock - external clock not used in Arduino
  TIMSK2 |= (1<<TOIE2) | (0<<OCIE2B);   //Timer2 Overflow Interrupt Enable
  TCNT2 = GamaTab[0];
  sei();   
}

void _init(void)    // define the pin mode
{
  DDRD=0xff;
  DDRC=0xff;
  DDRB=0xff;
  PORTD=0;
  PORTB=0;
  init_timer2();  // initial the timer for scanning the LED matrix
}





//
// r,g,b values range from 0=off to 15=full power
//
void SetPixel(byte x, byte y, byte r, byte g, byte b) {   
  byte mysurface;
  
  x &= 7;
  y &= 7;
  mysurface=1-surface;

  if (x & 1) {
      dots_color[mysurface][0][y][x >> 1] = g | (dots_color[mysurface][0][y][x >> 1] & 0xF0);
      dots_color[mysurface][1][y][x >> 1] = r | (dots_color[mysurface][1][y][x >> 1] & 0xF0);
      dots_color[mysurface][2][y][x >> 1] = b | (dots_color[mysurface][2][y][x >> 1] & 0xF0);
  } else {
      dots_color[mysurface][0][y][x >> 1] = (g << 4) | (dots_color[mysurface][0][y][x >> 1] & 0x0F);
      dots_color[mysurface][1][y][x >> 1] = (r << 4) | (dots_color[mysurface][1][y][x >> 1] & 0x0F);
      dots_color[mysurface][2][y][x >> 1] = (b << 4) | (dots_color[mysurface][2][y][x >> 1] & 0x0F);
  }
}





//==============================================================
void shift_1_bit(unsigned char LS)  //shift 1 bit of  1 Byte color data into Shift register by clock
{
  if(LS) {
    shift_data_1;
  } else {
    shift_data_0;
  }
  clk_rising;
}

//==============================================================
void flash_next_line(unsigned char line,unsigned char level) // scan one line
{
  disable_oe;
  close_all_line;
  open_line(line);
  shift_24_bit(line,level);
  enable_oe;
}

//==============================================================
void shift_24_bit(unsigned char line,unsigned char level)   // display one line by the color level in buff
{
  unsigned char color=0,row=0;
  unsigned char data0=0,data1=0;

  le_high;
  for(color=0;color<3;color++) { 
    for(row=0;row<4;row++) {
      data1=dots_color[surface][color][line][row]&0x0f;
      data0=dots_color[surface][color][line][row]>>4;

     //gray scale,0x0f aways light
     if(data0>level) {
        shift_1_bit(1);
      } else {
        shift_1_bit(0);
      }

      if(data1>level) {
        shift_1_bit(1);
      } else {
        shift_1_bit(0);
      }
    }
  }
  le_low;
}



//==============================================================
void open_line(unsigned char line)     // open the scaning line 
{
  switch(line) {
  case 0: 
      open_line0;
      break;
  case 1:
      open_line1;
      break;
  case 2:
      open_line2;
      break;
  case 3:
      open_line3;
      break;
  case 4:
      open_line4;
      break;
  case 5:
      open_line5;
      break;
  case 6:
      open_line6;
      break;
  case 7:
      open_line7;
      break;
  }
}



void FlipSurface() {
  surface=1-surface;
}



void ClearSurface() {
  byte c,y,x;

  for (c=0; c<3; c++) {
    for (y=0; y<8; y++) {
      for (x=0; x<4; x++) {
        dots_color[1-surface][c][y][x]=0;
      }
    }
  }

}     




//
//
//
void LoadLevel(char theLevel) {
  byte *p;
  byte data;
  byte  r,c;
  byte  i;
  

  Serial.print("Load level ");
  Serial.println(theLevel,DEC);

  p=sokomapData;// + levelNo*LEVELSIZE;

  do {
    // Clear the map
    for (int r=0; r<ROWS; r++) {
      for (int c=0; c<COLS; c++) {
        sokomap[r][c]=MAP_EMPTY;
      }
    }
  
  
    moves=pgm_read_byte_near(p++);
    pushes=pgm_read_byte_near(p++);
    c=moves/4;
    if ((moves%4)!=0) c++;
    for (i=0; i<c; i++) {
      lrud[i]=pgm_read_byte_near(p++);
    }
  
    // Plot the walls
    for (r=0; r<8; r++) {
      data=pgm_read_byte_near(p++);
      for (c=0; c<8; c++) {
        if ((data & (1<<c)) != 0) {
          sokomap[r][c]=MAP_WALL; 
        }
      }
    }
  
  
  // Plot the boxes
    Serial.print("Boxes: ");
    for (i=0; i<NRBOXES; i++) {
      data=pgm_read_byte_near(p++);
      if (data!=NOTINUSE) {
        Serial.print(data,HEX);
        Serial.print(" ");
        sokomap[data>>4][data&0x0F] |= MAP_BOX;
      }  
    }  
    Serial.println();
  
    // Plot the goals
    Serial.print("Goals: ");
    for (i=0; i<NRGOALS; i++) {
      data=pgm_read_byte_near(p++);
      if (data!=NOTINUSE) {
        Serial.print(data,HEX);
        Serial.print(" ");
        sokomap[data>>4][data&0x0F] |= MAP_GOAL;
      }  
    }  
    Serial.println();
  
    // Get coords for the player
    Serial.print("Player: ");
    data=pgm_read_byte_near(p++);
    Serial.print(data,HEX);
    playerY=data>>4;
    playerX=data&0x0F;
    Serial.println();
   
   theLevel--;
  } while (theLevel>0);
}



//
//
//
void RenderLevel(unsigned char cnt) {
  byte r,c;
  unsigned int color;

  // Plot the map onto the display using the specified colors
  for (int r=0; r<ROWS; r++) {
    for (int c=0; c<COLS; c++) {
      if ((sokomap[r][c]&(MAP_BOX|MAP_GOAL))==(MAP_BOX|MAP_GOAL)) color=COLOR_SOLVED;
      else if (sokomap[r][c]&MAP_GOAL) color=COLOR_GOAL;
      else if (sokomap[r][c]&MAP_BOX) color=COLOR_BOX;
      else if (sokomap[r][c]&MAP_WALL) color=COLOR_WALL;
      else color=COLOR_BACKGROUND;
      SetPixel(c, r, color>>8, (color>>4)&0x0f, color&0x0f);
    }
  }
  
  // If player is on a goal-square then alternare between the colors, else just show
  // a steady player color
  if ( ((sokomap[playerY][playerX]&MAP_GOAL)!=MAP_GOAL)  || (cnt&FLASHRATE)) {
    SetPixel(playerX,playerY, COLOR_PLAYER>>8, (COLOR_PLAYER>>4)&0x0f, COLOR_PLAYER&0x0f);
  }
}




byte ReadDirButtons() {
    int v;
    
    v=analogRead(6);
//    Serial.print("V="); Serial.println(v,DEC);

    if (v<127) return 0;
    if (v<380) return BUTTON_RIGHT;
    if (v<470) return BUTTON_DOWN;
    if (v<767) return BUTTON_LEFT;
    return BUTTON_UP;
}


void setup() {
  _init();
  Serial.begin(9600);
}



void DrawChar(char ch, int offset, byte r, byte g, byte b) {
  byte *p;
  byte data;
  int x;
  char y;

  p=ASCII_Space;

  if((ch>64)&&(ch<91)) p=ASCII_Char[ch-65]; 
  else if((ch>96)&&(ch<123)) p=ASCII_Char[ch-71];
  else if( (ch>='0')&&(ch<='9')) p=ASCII_Number[ch-48];

  for (y=0; y<8; y++) {
    data=pgm_read_byte_near(p++);
    for (x=0; x<6; x++) {
      if ((x+offset>=0) && (x+offset<=7)) {
        if ((data & (1<<(x+2))) != 0) {
          SetPixel(x+offset,7-y, r,g,b);
        }
      }
    }
  }
}


void DrawDigit(byte no, byte pos) {
  byte data;
  byte x,y;
  
  for (y=0; y<5; y++) {
    data=pgm_read_byte_near(SmallDigits+(no>>1)*5+y);
    for (x=0; x<3; x++) {
      if (data&(1<<(x+(no&1)*4))) {
        SetPixel(x+pos*4, y, 15,15,15);
      } else {
        SetPixel(x+pos*4, y, 0,0,0);
      }
    }
  }

}



char ScrollMessage(char *msg, byte r, byte g, byte b) {
  int pixels;
  int i;
  int v;
  byte button;
  
  pixels=6*strlen(msg);
  
  for (v=0; v<pixels; v++) {
    ClearSurface();
    for (i=0; i<strlen(msg); i++) {
      DrawChar(msg[i],i*6-v, r,g,b);
    }
    FlipSurface();
    for (i=0; i<10; i++) {
      delay(SCROLLSPEED/10);
      button=ReadDirButtons();
      if (button!=0) return button;
      random(0,255);
    }
  }    
  return 0;
}



//
//
//
void WaitForButtonRelease(boolean blank=false) {
  if (blank) {
    ClearSurface();
    FlipSurface();
  }
  do {
    delay(2);
  } while (ReadDirButtons()!=0);
  delay(2);
}



void loop() {
  byte  levelNo;
  char  res;
  int v;
  char  xDir, yDir;
  unsigned int cnt=0;
  byte x,y;
  byte presscnt;
  byte menu=false;
  byte automode=0;


  while (!ScrollMessage(" Sokodino", random(0,15),random(0,15), random(0,15)));
  WaitForButtonRelease(true);
 
  levelNo=1;
  LoadLevel(levelNo); 
  automode=0;
  menu=true;
    
  for (;;) {

    while (menu) {

      do {res=ScrollMessage(" Restart", 15,0,0);} while (res==0);
        WaitForButtonRelease();
        if (res==BUTTON_RIGHT) {
          menu=false;
          LoadLevel(levelNo); 
          break;
        }

        do {res=ScrollMessage(" Undo", 15,15,0);} while (res==0);
        WaitForButtonRelease();
        if (res==BUTTON_RIGHT) {
        }

        do {res=ScrollMessage(" Auto", 0,15,0);} while (res==0);
        WaitForButtonRelease();
        if (res==BUTTON_RIGHT) {
          menu=false;
          LoadLevel(levelNo); 
          automode=1;
          break;
        }

        do {res=ScrollMessage(" Level", 0,0,15);} while (res==0);
        WaitForButtonRelease();
        if (res==BUTTON_RIGHT) {
          while (true) {
            ClearSurface();
            DrawDigit(levelNo/10,0);
            DrawDigit(levelNo%10,1);
            FlipSurface();
            v=ReadDirButtons();
            if ((v==BUTTON_UP) && (levelNo>0)) levelNo--;
            if ((v==BUTTON_DOWN) && (levelNo<50)) levelNo++;
            if (v==BUTTON_RIGHT) break;
            delay(100);
          }
          menu=false;
          WaitForButtonRelease();
          LoadLevel(levelNo); 
          break;
        }
        
      } // End of menu handling
        
      ClearSurface();
      RenderLevel(cnt++);
      FlipSurface();

      yDir=0;
      xDir=0;
      if (automode==0) {
        v=ReadDirButtons();
        if ((v==BUTTON_UP)    && (playerY>0)) yDir=-1;
        if ((v==BUTTON_DOWN)  && (playerY<7)) yDir=1;
        if ((v==BUTTON_LEFT)  && (playerX>0)) xDir=-1;
        if ((v==BUTTON_RIGHT) && (playerX<7)) xDir=1;
      } else {
        v=lrud[(automode-1)/4];
        if (((automode-1)%4)==0) v=v&0x03;
        if (((automode-1)%4)==1) v=(v>>2)&0x03;
        if (((automode-1)%4)==2) v=(v>>4)&0x03;
        if (((automode-1)%4)==3) v=(v>>6)&0x03;
 
        for (byte i=0; i<100; i++) {
          ClearSurface();
          RenderLevel(cnt++);
          FlipSurface();
          delay(10);
          cnt++; 
        }
        automode++;
        if (automode>moves) automode=0;
      }


      v=sokomap[playerY+yDir][playerX+xDir];

      if (v==0) {  // Empty
        // Move player there
        playerX+=xDir;
        playerY+=yDir;

      } else if ((v&(MAP_GOAL|MAP_BOX))==MAP_GOAL) {  // Goal only
        // Move player there
        playerX+=xDir;
        playerY+=yDir;

      } else if (v&MAP_BOX) { // Box
        x=playerX+(xDir*2);
        y=playerY+(yDir*2);
        //Only check what what's behind the box if still inside the field 
        if ((x>=0) && (x<=7) && (y>=0) && (y<=7)) {
          // Now check what's behind the box
          if ((sokomap[y][x]==0) || (((sokomap[y][x]&(MAP_GOAL|MAP_BOX))==MAP_GOAL))) { //Empty or goal only
            // The box can be pushed so move both box and player
            sokomap[playerY+yDir][playerX+xDir]&=~MAP_BOX;
            sokomap[y][x]|=MAP_BOX;
            playerX+=xDir;
            playerY+=yDir;
          }
        }
      }

      // Wait for button release if any button was pressed 
      if ((xDir!=0)  || (yDir!=0)) {
        delay(2);  // Debounce
        presscnt=0;
        while (ReadDirButtons()!=0) {
          // Enter menu if a button pressed for 2 seconds
          delay(10);
          presscnt++;
          if (presscnt>200) {
            WaitForButtonRelease(true);
            menu=true;
            break;
          }
        };
        delay(2);  // More debounce
      }

      delay(10);
      
  }
}










