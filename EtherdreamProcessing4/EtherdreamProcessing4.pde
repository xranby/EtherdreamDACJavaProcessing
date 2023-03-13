Etherdream e = new Etherdream(this);

void setup() 
{
  size(200, 200);
  frameRate(30);
}

void draw() { 
  background(204);
}

DACPoint[] getDACPoints() {
    DACPoint[] result = new DACPoint[600];

    for (int i = 0; i < 600; i++) {

        /* x,y   int min -32767 to max 32767
         * r,g,b int min 0 to max 65535
         *
         * NOTE: TTL r,g,b transistors float from ~26100 to ~26800 up to ~27400
         * this can be used as a hack to output reduced  on
         * when using undimmable TTL laser driver boards
         * 
         * 26800, 26800, 27900  all dimmed  white
         * 26200,     0,     0  only dimmed red
         *     0, 26500,     0  only dimmed green
         *     0,     0, 27400  only dimmed blue
         */

        result[i] = new DACPoint((int) (32767 * Math.sin((i / 12.0))), (int) (32767 * Math.cos(i / 24.0)),
                                                    0 /* red */,     65535 /* green */,     0 /* blue */);
   }  
   return result;
}
