import java.util.Vector;
Vector<Kula> kulor = new Vector<Kula>(); 
Kula sol;
int laserMax = 65535;
int mx = 65535/2;
int mi = -65535/2;
void setup(){
  size(400,400,P3D);
  Kula k;
  sol = new Kula(color(#FFE603),color(#FF8103),new Position(50,50),12);

  kula(#FFFFFF);
  kulor.add(sol);
  
  k = new Kula(color(#BF07F7),color(220),new Position(50,50),8);
  
  
  kulor.add(k);
  k = new Kula(color(#FA2803),color(220),new Position(50,50),8);
  kulor.add(k);
  
  k = new Kula(color(#C8FA03),color(220),new Position(50,50),8);
  kulor.add(k);
  
  k = new Kula(color(#E9FF03),color(#FC38E9),new Position(50,50),8);
  kulor.add(k);
  
  k = new Kula(color(#001AFA),color(#001AFA),new Position(50,50),8);
  kulor.add(k);
  
  k = new Kula(color(#AE56ED),color(#AE56ED),new Position(50,50),8);
  kulor.add(k);
  
  kula(#AE56ED);
  kula(#F5741E);
  kula(#554840);

  ArrayList<Point> p = new ArrayList<Point>();
  for(int i=0; i<20; i++){
      int y = ((laserMax / 20))-mx;
      p.add( new Point(mi,y));
      p.add( new Point(mx,y)); 
  }
  laserpoint = p;
  
  Etherdream laser = new Etherdream(this);  
  //for(int i=0;i<100;i++)
  //  kula(#FCF5FC);  
}

void kula(int f){
  Kula k = new Kula(color(f),color(f),new Position(50,50),8);
  kulor.add(k); 
}
int frame = 0;
boolean toggleLines = false;
void draw(){
  if(mousePressed==false){
  background(10);
  toggleLines=!toggleLines;
   }
   
 /* for(int xx=0;xx<width;xx+=10)
    for(int yy=0;yy<height;yy+=10)
       sol.visa(xx, yy, sol);
 */
  
  ArrayList<Point> p = new ArrayList<Point>();
  /*for(int i=0; i<20; i++){
      int y = ((laserMax / 20))-mx;
      p.add( new Point(mx,y)); 
  } */
  for( Kula kula: kulor){
    kula.rita();
    if(frame%3==0){
      kula.rorpodig();
      kula.roteramot(sol);
    }
    
  if(mousePressed==true){
       p.add( new Point(int (kula.pos.x/width*mx),int (kula.pos.y/height*mx)));
  }
       p.add( new Point(int (kula.pos.x/width*mx),int (kula.pos.y/height*mx),mx-10,mx-10,0));   
  }
 
 
  laserpoint = p;
  frame++;
//k.rita();
//k.rorpodig();  
}


// store uncoverted laser points updated by draw()
// to be converted
// when the laser request new points using the getDACPoints
// callback
volatile ArrayList<Point> laserpoint;

// Callback used by Etherdream laser to fetch next points to display
// helper functions to add extra points are found from line 200 and down in this file
DACPoint[] getDACPoints() {
    
    return pointsMinimum(getDACPointsAdjusted(laserpoint.toArray(new Point[0])),600);
}

// Etherdream help functions below to beam lines

import java.util.Queue;
import java.util.List;
import java.util.Collections;

enum PointType {
  L,
  C;
}

public class Point {
  final PointType type;
  public final int x, y, r, g, b;
  Point(int x, int y, int r, int g, int b) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;  
     type = PointType.L;
  }
  Point(int x, int y, int r, int g, int b, PointType p) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;  
     type = p;
  }
  
  Point(int x, int y) {
     this.x=x;this.y=y;this.r=0;this.g=0;this.b=0;
     type = PointType.L;
  }
  
  Point(int x, int y, PointType p) {
     this.x=x;this.y=y;this.r=0;this.g=0;this.b=0;
     type = p;
  }
}

DACPoint[] getDACPointsDelayAdjusted(Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    }
    return result;
}

DACPoint[] getDACPointsLinearAdjusted(Point a, Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(a.x+(i*((p.x-a.x)/mult)), a.y+(i*((p.y-a.y)/mult)),
            p.r,     p.g,     p.b);
    }
    return result;
}


DACPoint[] getDACPointsCircleAdjusted(Point a, Point p, Point c, int mult, float d) {
    //float d = 0.023*mult+0.627;
    DACPoint[] result = new DACPoint[mult];
    int x = mx;
    int y = mx;
    int ip=0;
    for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
        
        result[ip] = new DACPoint(x, y,
            p.r,     p.g,     p.b);
        ip++;
    }
    return result;
}

/**
 * Generate more precise laser lines by
 * adding extra points in between
 *
 * mult = 10; float d = 0.066;// round
 * mult = 15; float d = 0.066;// round
 * mult = 20; float d = 0.166;// round
 * mult = 25; float d = 0.14; // looks OK
 * mult = 50; float d = 0.117; // flickery due to reduced draw speed
 * mult = 100; float d = 0.05; // flickery due to reduced draw speed
 * mult = 150; float d = 0.036; // flickery due to reduced draw speed
 */
 


DACPoint[] getDACPointsLerpAdjusted(Point a, Point p, int mult, float d) {
    //float d = 0.023*mult+0.627;
    DACPoint[] result = new DACPoint[mult];
    int x = a.x;
    int y = a.y;
    int ip=0;
    for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
        
        /*int linearx = a.x+(i*((p.x-a.x)/mult));
        int lineary = a.y+(i*((p.y-a.y)/mult));
        int sx = xToScreenX(linearx);
        int sy = yToScreenY(lineary);
        
        color c = get(sx,sy);
        
       
        //System.out.println("sx "+sx+" sy "+sy+"r"+r);
        
        int r = (int)red(c);
        
        int lr=0;
        if(r>128){
          lr = on;
        } else {
          lr =0;
        }
        
        int g = (int)green(c);
        
        int lg=0;
        if(g>128){
          lg = on;
        } else {
          lg =0;
        }
       
       int b = (int)blue(c);
        
        int lb=0;
        if(b>128){
          lb = on;
        } else {
          lb =0;
        }*/
        
        result[ip] = new DACPoint(x, y,
            p.r,     p.g,     p.b);
        ip++;
    }
    return result;
}

DACPoint[] getDACPoints(Point p) {
    DACPoint[] result = new DACPoint[1];
    result[0] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    return result;
}

int distance(Point a, Point b) {
  return (int)sqrt(((a.x-a.y)*(a.x-a.y))+((b.x-b.y)*(b.x-b.y)));
}

DACPoint[] getDACPointsAdjusted(Point[] points) {
    DACPoint[] result = new DACPoint[0];
    
    Point first = points[0];
    Point last = points[points.length-1];
    for(Point p: points){
      //int l = distance(last,p);
      //System.out.println(l);
      
      // delay adjusted
      //result = concatPoints(result,getDACPointsDelayAdjusted(p,22));
     
      //result = concatPoints(result,getDACPointsLinearAdjusted(last,p,20));
     
      //lerp adjusted
      //result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      switch(p.type){
        case L:
           result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
        break;
        case C:
           result = concatPoints(result,getDACPointsCircleAdjusted(last,p,first,25,0.14));
        break;
      }
      
     /*
      
      if((l<500)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,5,0.14));
      } else if((l<7000)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,10,0.14));
      } else if((l<13000)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,15,0.14));
      } else {
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      }*/
      
      last = p;
    }
    return result;
}

DACPoint[] concatPoints(DACPoint[]... arrays) {
        // Determine the length of the result array
        int totalLength = 0;
        for (int i = 0; i < arrays.length; i++) {
            totalLength += arrays[i].length;
        }

        // create the result array
        DACPoint[] result = new DACPoint[totalLength];

        // copy the source arrays into the result array
        int currentIndex = 0;
        for (int i = 0; i < arrays.length; i++) {
            System.arraycopy(arrays[i], 0, result, currentIndex, arrays[i].length);
            currentIndex += arrays[i].length;
        }

        return result;
}

DACPoint[] pointsMinimum(DACPoint[] p,int minimum) {
  
  if(p.length>=minimum){
      return p;
  }
  
  if(p.length<=(minimum/4)){
      return pointsMinimum(concatPoints(p,p,p,p),minimum);    
  }
  
  if(p.length<=(minimum/3)){
      return pointsMinimum(concatPoints(p,p,p),minimum);
  }
  
  return pointsMinimum(concatPoints(p,p),minimum);  
}

color numberToColor(Integer o) {
  colorMode(RGB, 255);
  switch(o){
    case 1:
        return color(255,0,0); // red
    case 2:
        return color(0,255,0); // green
    case 3:
        return color(255,255,0); // yellow
    case 4:
        return color(0,0,255); // green
    case 5:
        return color(0,255,255); // cyan
    case 6: 
        return color(255,0,255); // violet
    case 7:
        return color(255,255,255); // white
    default:
        return color(255,0,255);
  }
}
