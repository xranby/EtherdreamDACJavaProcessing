class Kula {
public color innerfarg;
color ytterfarg;
public Position pos;
int storlek;
//Position v;
Riktning r;

public Kula(color f,color fy,Position p,int s){
  innerfarg=f;
  ytterfarg=fy;
  pos=p;
  storlek=s;
  //v=new Position(-2.5+random(5),-2.5+random(5));
  r=new Riktning(random(2*PI),random(5));

}

public void rita() {
 stroke(ytterfarg);
 fill(innerfarg);
 ellipse(pos.x,pos.y,storlek,storlek); 
}

//Kula = gojo
public void roteramot(Kula nap){

 float ax = pos.x-nap.pos.x;
 float ay = pos.y-nap.pos.y;

 //pytagoras räkna ut avståndet
 float d = sqrt(ax*ax+ay*ay);
 
 //float vink = ax/ay;
 float vink = atan(ax/ay);
 
 //line(pos.x,pos.y,pos.x+sin(vink)*d,pos.y+cos(vink)*d);
 
 if(this!=nap){
   //r.vinkel=vink;
   r.vinkel+=vink*100/d;
 }
}

void visa(float x, float y, Kula nap){
 float ax = x-nap.pos.x;
 float ay = y-nap.pos.y; 
 
  float d = sqrt(ax*ax+ay*ay);
 float vink = ax/ay;
 //float vink = tan(ax/ay);
 
 
 
 line(x,y,x+sin(vink)*d/2,y+cos(vink)*d/2);

}

public void rorpodig() {
 pos = pos.plus(r);
 if(pos.x<0){
   pos.x=width;
 }
 if(pos.x>width){
   pos.x=0;
 }
 if(pos.y<0){
   pos.y=height;
 }
 if(pos.y>height){
   pos.y=0;
 }
}

}
