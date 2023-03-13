class Position {
float x;
float y;

Position(float nx, float ny){
  x=nx;
  y=ny;
}

public Position plus(Position v){
  Position r = new Position(x+v.x,y+v.y);
  return r;
}

public Position plus(Riktning r){
  
  //
  //
  float xx =sin(r.vinkel)*r.fart;
  float yy =cos(r.vinkel)*r.fart;
  
  Position p = new Position(x+xx,y+yy);
  return p;
}

}
