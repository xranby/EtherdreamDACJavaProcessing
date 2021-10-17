// The Flock (a list of Boid objects)

class Flock {
  ArrayList<Boid> boids; // An ArrayList for all the boids

  Flock() {
    boids = new ArrayList<Boid>(); // Initialize the ArrayList
  }

  ArrayList<Point> run() {
    
    ArrayList<Point> p = new ArrayList<Point>();
  
    for (Boid b : boids) {
      b.run(boids,p);  // Passing the entire list of boids to each boid individually
    }
    
    return p;
  }

  void addBoid(Boid b, int max) {
    boids.add(b);
    if(boids.size()>max){
      boids.remove(0);
    }
  }

}
