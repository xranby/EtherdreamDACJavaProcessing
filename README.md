# EtherdreamDACJavaProcessing
Etherdream DAC for Java and Processing 4
by Xerxes Rånby 2021

The Etherdream.java can be compiled and run standalone
the only dependency is the OpenJDK 11 runtime: 

    javac Etherdream.java
    java Etherdream

Processing 4 also uses JDK 11 you can add a new tab for the Etherdream.pde
content and then add the following to the sketch:

    new Etherdream(this);

Etherdream will then use a callback function to fetch the laser points
The DAC can only receive up to 3778 ponts at a time,
the ponts are consumed rapidly by the laser 34464 points/second
The callback will get called as soon as there is room to refill more
points into the Etherdream DAC.

    // Callback used by Etherdream laser to fetch next points to display
    // Example below to create a smooth green circle
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

            result[i] = new DACPoint((int) (32767 * Math.sin((i / 24.0))), (int) (32767 * Math.cos(i / 24.0)),
                                                        0 /* red */,     65535 /* green */,     0 /* blue */);
       }  
       return result;
    }

Advanced example:
R-WDML (Re-wake the Dead with Musical Light) for Processing 4
laser visualization for midi playback demonstration:
https://www.instagram.com/p/CJk7w8KAcH2/
