int MAX_ENEMIES = 3;
int MAX_LIVES = 100;

// The picture that the player must unveil
PImage backgroundImage;

// The custom mask (adapted to the specific picture) that is hidding the picture
PImage maskImage;

// An internal (invisible) mask that determines if a point is inside the border (#FFFFFF, playable region)
// or outside of it (#000000, already unveiled region). Used to determine if an enemy has been killed (is
// now on the unveiled region).
PImage filledImage;

PFont scoreFont;

Cursor cursor;
Path borderPath;
Path excursionPath;
ArrayList<Enemy> enemies = new ArrayList<Enemy>();
boolean pause = false;
int lives;
int score;
int maskInitialCount;
int maskFreedCount;
boolean gameOver;
boolean gameOverAccepted;

class Cursor {
  int colorIndex = 0;
  int x;
  int y;
  int speed = 10;
  int segmentIndex = 0;
  boolean excursionMode = false;

  Cursor() {
    Segment s = borderPath.segments.get(0);
    x = s.x0;
    y = s.y0;
  }

  void move(int keyCode) {
    int x0 = x;
    int y0 = y;
    int nextSegmentIndex = borderPath.getNextSegmentIndex(segmentIndex, x, y, keyCode);
    Segment s = borderPath.segments.get(segmentIndex);
    if (nextSegmentIndex >= 0) {
      segmentIndex = nextSegmentIndex;
      s = borderPath.segments.get(segmentIndex);
    }

    // FIXME: Disallow loops (the path crossing over itself) in excursions!!!

/*
    println("filledDirection: ", directionToString(s.filledDirection), ", excursionMode: ", excursionMode);
*/

    // Excursions from square corners should be able to be started in two directions. We should consider
    // the reversedFilledDirection from each of the segments that conform the corner.
    IntList validDirectionsForStartingExcursion = new IntList();
    for (Segment sg : borderPath.findSegments(x, y))
      validDirectionsForStartingExcursion.append(reverseDirection(sg.filledDirection));
    boolean canStartExcursion = excursionPath != null && excursionPath.segments.size() == 0 && validDirectionsForStartingExcursion.hasValue(keyCode);
    boolean canExcursion = excursionMode && (excursionPath.segments.size() > 0 || canStartExcursion);
    
    switch (keyCode) {
      case LEFT:
        if (!excursionMode && s.isHorizontal() && x>min(s.x0, s.x1) || canExcursion)
          x-=speed;
        break;
      case RIGHT:
        if (!excursionMode && s.isHorizontal() && x<max(s.x0, s.x1) || canExcursion)
          x+=speed;
        break;
      case UP:
        if (!excursionMode && s.isVertical() && y>min(s.y0, s.y1) || canExcursion)
          y-=speed;
        break;
      case DOWN:
        if (!excursionMode && s.isVertical() && y<max(s.y0, s.y1) || canExcursion)
          y+=speed;
        break;       
    }
    if (excursionMode && (x0 != x || y0 != y))
      updateExcursion(x0, y0, x, y);
  }

  void setExcursionMode(boolean excursionMode) {
    this.excursionMode = excursionMode; 
  }

  void updateExcursion(int x0, int y0, int x, int y) {
    Segment deltaSegment = new Segment(x0, y0, x, y, -1);
    Segment currentSegment = null;
    for (Segment s : excursionPath.segments) {
      if (x0 == s.x1 && y0 == s.y1) {
        currentSegment = s;
        break;
      }
    }

/*
    println("CurrentSegment: ", (currentSegment != null) ? currentSegment.toString() : "null");
    println("DeltaSegment: ", deltaSegment.toString());
*/

    if (currentSegment == null) {
      currentSegment = deltaSegment;
      excursionPath.segments.add(currentSegment);
    } else {
      if (currentSegment.getDirection() == deltaSegment.getDirection()
        || currentSegment.getDirection() == reverseDirection(deltaSegment.getDirection())) {
        currentSegment.merge(deltaSegment);
        if (currentSegment.isEmpty())
          excursionPath.segments.remove(excursionPath.segments.size()-1);
      } else {
        excursionPath.segments.add(deltaSegment);
      }
    }
/*
    println("Excursion path: ", excursionPath.toString());
*/
    Segment intersectingBorderPathSegment = excursionPath.findOtherPathIntersectedSegment(borderPath);
    if (intersectingBorderPathSegment != null) {
      cursor.setExcursionMode(false);
      borderPath.merge(excursionPath);
      updateMask();
      segmentIndex = borderPath.getSegmentIndex(x, y);
      assert(segmentIndex != -1);
      excursionPath = null;

      ArrayList<Enemy> deadEnemies = new ArrayList<Enemy>();
      for (Enemy e : enemies)
        if (filledImage.pixels[width * e.y + e.x] == #000000) {
          score += e.worth;
          deadEnemies.add(e);
        }
      enemies.removeAll(deadEnemies);
      
      // FIXME: Detect if the not yet filled region is too small and declare stage completion in that case.
      
/*
      println("Excursion finished properly. New borderPath:");
      println(borderPath.toString());
*/
    }
  }

  void draw() {
    strokeWeight(4);
    if (excursionMode) {
      stroke(color(0xFF-colorIndex, 0, 0));
      fill(color(colorIndex, 0, 0));
    } else {
      stroke(color(0xFF-colorIndex, 0xFF-colorIndex, 0xFF-colorIndex));
      fill(color(colorIndex, colorIndex, colorIndex));
    }
    colorIndex = (colorIndex + 0x05) % 0x100; 
    rectMode(CENTER);
    rect(x, y, 20, 20);
  }
}

class Segment {
  int x0, y0, x1, y1;
  // Direction constant explaining the direction where the filled part of the path is
  int filledDirection;
  
  Segment(int x0, int y0, int x1, int y1, int filledDirection) {
    this.x0 = x0;
    this.y0 = y0;
    this.x1 = x1;
    this.y1 = y1;
    this.filledDirection = filledDirection;
  }

  boolean isVertical() {
    return x0 == x1 && y0 != y1;
  }

  boolean isHorizontal() {
    return x0 != x1 && y0 == y1;
  }

  boolean isEmpty() {
    return x0 == x1 && y0 == y1;
  }

  boolean intersects(Segment other) {
    boolean result = false;
    if (isHorizontal() && other.isHorizontal() && other.y0 == y0
      && !(max(other.x0, other.x1) < min(x0, x1) || max(x0, x1) < min(other.x0, other.x1)))
      result=true;
    else if (isVertical() && other.isVertical() && other.x0 == x0
      && !(max(other.y0, other.y1) < min(y0, y1) || max(y0, y1) < min(other.y0, other.y1)))
      result=true;
    else if (isHorizontal() && other.isVertical()
      && min(x0, x1) <= other.x0 && max(x0, x1) >= other.x0
      && min(other.y0, other.y1) <= y0 && max(other.y0, other.y1) >= y0)
      result=true;
    else if (isVertical() && other.isHorizontal()
      && min(y0, y1) <= other.y0 && max(y0, y1) >= other.y0
      && min(other.x0, other.x1) <= x0 && max(other.x0, other.x1) >= x0)
      result=true;
/*
    println(toString(), " intersects ", other.toString(), ": ", result);
*/
    return result;
  }

  boolean intersects(int x, int y) {
    boolean result = false;
    if (isHorizontal() && y == y0 && min(x0, x1) <= x && max(x0, x1) >= x)
      result=true;
    else if (isVertical() && x == x0 && min(y0, y1) <= y && max(y0, y1) >= y)
      result=true;
/*
    println(toString(), " intersects [", x, ", ", y,"]: ", result);
*/
    return result;
  }

  int getDirection() {
    if (x0 < x1) return RIGHT;
    if (x0 > x1) return LEFT;
    if (y0 < y1) return DOWN;
    if (y0 > y1) return UP;
    return -1;
  }
  
  void merge(Segment other) {
    assert(x1 == other.x0 && y1 == other.y0 || x0 == other.x1 && y0 == other.y1);
    if (x1 == other.x0 && y1 == other.y0) {
      x1 = other.x1;
      y1 = other.y1;
    } else {
      x0 = other.x0;
      y0 = other.y0;
    }
    if (filledDirection == -1)
      filledDirection = other.filledDirection;
  }
  
  ArrayList<Segment> split(int x, int y) {
    assert(intersects(x, y));
    ArrayList<Segment> result = new ArrayList<Segment>();
    result.add(new Segment(x0, y0, x, y, filledDirection));
    result.add(new Segment(x, y, x1, y1, filledDirection));
    return result;
  }
  
  int distance(int xA, int yA, int xB, int yB) {
    return abs(xB-xA) + abs(yB-yA);
  }

  int distance() {
    return distance(x0, y0, x1, y1);
  }

  Segment reversed() {
    return new Segment(x1, y1, x0, y0, filledDirection); 
  }
  
  String toString() {
    return "[" + x0 + ", " + y0 + "] - [" + x1 + ", " + y1 + "] (DIR: " + directionToString(getDirection()) + ", FILL: " + directionToString(filledDirection) + ")";
  }
}

class Path {
  ArrayList<Segment> segments = new ArrayList<Segment>();
  color strokeColor;

  Path() {
    strokeColor = color(0xFF, 0x00, 0x00);
  }

  Path(int screenWidth, int screenHeight) {
    // Initial path set to the border of the screen
    segments.add(new Segment(50, 50, screenWidth-50, 50, UP));
    segments.add(new Segment(screenWidth-50, 50, screenWidth-50, screenHeight-50, RIGHT));
    segments.add(new Segment(screenWidth-50, screenHeight-50, 50, screenHeight-50, DOWN));
    segments.add(new Segment(50, screenHeight-50, 50, 50, LEFT));
    strokeColor = 0xFF;
  }
  
  int getNextSegmentIndex(int currentSegmentIndex, int x, int y, int direction) {
    int nextSegmentIndex = -1;
    int potentialNextSegmentIndex = -1;
    Segment currentSegment = segments.get(currentSegmentIndex);
    Segment potentialNextSegment = null;
    int potentialNextSegmentDirection = -1;
    if (x == currentSegment.x0 && y == currentSegment.y0) {
      potentialNextSegmentIndex = (currentSegmentIndex + segments.size() - 1) % segments.size();
      potentialNextSegment = segments.get(potentialNextSegmentIndex);
      assert(currentSegment.x0 == potentialNextSegment.x1 && currentSegment.y0 == potentialNextSegment.y1);
      potentialNextSegmentDirection = reverseDirection(potentialNextSegment.getDirection());
    } if (x == currentSegment.x1 && y == currentSegment.y1) {
      potentialNextSegmentIndex = (currentSegmentIndex + segments.size() + 1) % segments.size();
      potentialNextSegment = segments.get(potentialNextSegmentIndex);
      assert(currentSegment.x1 == potentialNextSegment.x0 && currentSegment.y1 == potentialNextSegment.y0);
      potentialNextSegmentDirection = potentialNextSegment.getDirection();
    }
    
    /*
    println("currentSegment: (", currentSegmentIndex, ") [", currentSegment.x0, ", ", currentSegment.y0, "] - [", currentSegment.x1, ", ", currentSegment.y1, "]");
    if (potentialNextSegment != null)
      println("potentialNextSegment: (", potentialNextSegmentIndex, ") ",
        "[", potentialNextSegment.x0, ", ", potentialNextSegment.y0, "] - ",
        "[", potentialNextSegment.x1, ", ", potentialNextSegment.y1, "]",
        " (", directionToString(potentialNextSegmentDirection), ")");
    else
      println("potentialNextSegment: (", potentialNextSegmentIndex, ")";
    */

    if (direction == potentialNextSegmentDirection)
      nextSegmentIndex = potentialNextSegmentIndex;

    return nextSegmentIndex;
  }

  Segment findOtherPathIntersectedSegment(Path other) {
    if (segments.size() < 1)
      return null;
    Segment thisPathLastSegment = segments.get(segments.size() - 1);
    Segment otherPathIntersectedSegment = null;
    for (Segment s : other.segments) {
      if (s.intersects(thisPathLastSegment.x1, thisPathLastSegment.y1)) {
        otherPathIntersectedSegment = s;
        break;
      }
    }
/*
    println("findOtherPathIntersectedSegment: ", (otherPathIntersectedSegment != null) ? otherPathIntersectedSegment.toString() : "null");
*/
    return otherPathIntersectedSegment;
  }
  
  int getSegmentIndex(int x, int y) {
    int result = -1;
    for (int i = 0; i<segments.size(); i++) {
      Segment s = segments.get(i);
      if (s.intersects(x, y)) {
        result = i;
        break;
      }
    }
    return result;
  }

  // Corner points may belong to up to 2 segments
  ArrayList<Segment> findSegments(int x, int y) {
    ArrayList<Segment> result = new ArrayList<Segment>();
    for (Segment s : segments) {
      if (s.intersects(x, y))
        result.add(s);
    }
    return result;
  }

  void merge(Path other) {
    // Typically, "this" is borderPath and "other" is excursionPath.
    assert(other.segments.size() > 0);

    Segment otherFirstSegment = other.segments.get(0);
    Segment otherLastSegment = other.segments.get(other.segments.size() - 1);
    int startSegmentIndex = getSegmentIndex(otherFirstSegment.x0, otherFirstSegment.y0);
    int endSegmentIndex = getSegmentIndex(otherLastSegment.x1, otherLastSegment.y1);
    
    boolean mustReverseOther = false;
    if (startSegmentIndex > endSegmentIndex)
      mustReverseOther = true;
    
    Segment endSegment = segments.get(endSegmentIndex);
    Segment startSegment = segments.get(startSegmentIndex);
    
    if (startSegmentIndex == endSegmentIndex
      && startSegment.distance(startSegment.x0, startSegment.y0, otherFirstSegment.x0, otherFirstSegment.y0)
         > startSegment.distance(startSegment.x0, startSegment.y0, otherLastSegment.x1, otherLastSegment.y1))
      mustReverseOther = true;

    if (mustReverseOther) {
      other = other.reversed();
      otherFirstSegment = other.segments.get(0);
      otherLastSegment = other.segments.get(other.segments.size() - 1);
      startSegmentIndex = getSegmentIndex(otherFirstSegment.x0, otherFirstSegment.y0);
      endSegmentIndex = getSegmentIndex(otherLastSegment.x1, otherLastSegment.y1);
      endSegment = segments.get(endSegmentIndex);
      startSegment = segments.get(startSegmentIndex);
    }
    
    // Split the start and end segments and leave only the start first half and the end second half
    // in the borderPath before merging the excursionPath
    ArrayList<Segment> beforeStart = new ArrayList<Segment>();
    for (int i = 0; i < startSegmentIndex; i++)
      beforeStart.add(segments.get(i));
    ArrayList<Segment> startSplit = startSegment.split(otherFirstSegment.x0, otherFirstSegment.y0); 
    beforeStart.add(startSplit.get(0));
    
    ArrayList<Segment> afterEnd = new ArrayList<Segment>();
    ArrayList<Segment> endSplit = endSegment.split(otherLastSegment.x1, otherLastSegment.y1); 
    afterEnd.add(endSplit.get(1));
    for (int i = endSegmentIndex + 1; i < segments.size(); i++)
      afterEnd.add(segments.get(i));
    
    ArrayList<Segment> fromStartToEnd = new ArrayList<Segment>();
    if (startSegment == endSegment) {
      Segment s1 = startSplit.get(1);
      Segment s2 = endSplit.get(0);
      fromStartToEnd.add(new Segment(s1.x0, s1.y0, s2.x1, s2.y1, s1.filledDirection)); 
    } else {
      fromStartToEnd.add(startSplit.get(1));
      for (int i = startSegmentIndex + 1; i < endSegmentIndex; i++) {
        fromStartToEnd.add(segments.get(i));
      }
      fromStartToEnd.add(endSplit.get(0));
    }

/*
    println("mustReverseOther: ", mustReverseOther);
    println("beforeStart: ", toString(beforeStart));
    println("excursion: ", toString(other.segments));
    println("afterEnd: ", toString(afterEnd));
    println("fromStartToEnd: ", toString(fromStartToEnd));
*/

    // Two possible polygon splits. We choose the one with the biggest area.
    ArrayList<Segment> segmentsA = new ArrayList<Segment>();
    segmentsA.addAll(beforeStart);
    segmentsA.addAll(other.segments);
    segmentsA.addAll(afterEnd);
    segmentsA = sanitizeSegments(segmentsA);

    ArrayList<Segment> segmentsB = new ArrayList<Segment>();
    segmentsB.addAll(other.reversed().segments);
    segmentsB.addAll(fromStartToEnd);
    segmentsB = sanitizeSegments(segmentsB);

    if (area(segmentsA) >= area(segmentsB))
      segments = segmentsA;
    else
      segments = segmentsB;

/*
    println("segmentsA: ", segmentsA.toString());
    println("segmentsB: ", segmentsB.toString());
*/
    recomputeFilledDirection();
  }
  
  Path reversed() {
    Path reversedPath = new Path();
    reversedPath.strokeColor = strokeColor;
    for (int i = segments.size() - 1; i >= 0; i--)
      reversedPath.segments.add(segments.get(i).reversed());
    return reversedPath;
  }
  
  void recomputeFilledDirection() {
    int lastFilledDirection = -1;
    int lastDirection = -1;
    int newDirection = -1;

/*
    println("recomputeFilledDirection():");
*/

    for (int j = 0; j < 2; j++) {
/*
      println("j: " + j);
*/
      for (int i = 0; i < segments.size(); i++) {
        Segment s = segments.get(i);
        newDirection = s.getDirection();
        if (s.filledDirection == -1 && lastFilledDirection != -1 && lastDirection != -1) {
          switch (lastDirection) {
            case RIGHT:
              switch (newDirection) {
                case UP:
                  switch (lastFilledDirection) {
                    case UP:
                      s.filledDirection = LEFT;
                      break;
                    case DOWN:
                      s.filledDirection = RIGHT;
                      break;
                  }
                  break;
                case DOWN:
                  switch (lastFilledDirection) {
                    case UP:
                      s.filledDirection = RIGHT;
                      break;
                    case DOWN:
                      s.filledDirection = LEFT;
                      break;
                  }
                  break;
              }
              break;
            case LEFT:
              switch (newDirection) {
                case UP:
                  switch (lastFilledDirection) {
                    case UP:
                      s.filledDirection = RIGHT;
                      break;
                    case DOWN:
                      s.filledDirection = LEFT;
                      break;
                  }
                  break;
                case DOWN:
                  switch (lastFilledDirection) {
                    case UP:
                      s.filledDirection = LEFT;
                      break;
                    case DOWN:
                      s.filledDirection = RIGHT;
                      break;
                  }
                  break;
              }
              break;
            case UP:
              switch (newDirection) {
                case RIGHT:
                  switch (lastFilledDirection) {
                    case RIGHT:
                      s.filledDirection = DOWN;
                      break;
                    case LEFT:
                      s.filledDirection = UP;
                      break;
                  }
                  break;
                case LEFT:
                  switch (lastFilledDirection) {
                    case RIGHT:
                      s.filledDirection = UP;
                      break;
                    case LEFT:
                      s.filledDirection = DOWN;
                      break;
                  }
                  break;
              }
              break;
            case DOWN:
              switch (newDirection) {
                case RIGHT:
                  switch (lastFilledDirection) {
                    case RIGHT:
                      s.filledDirection = UP;
                      break;
                    case LEFT:
                      s.filledDirection = DOWN;
                      break;
                  }
                  break;
                case LEFT:
                  switch (lastFilledDirection) {
                    case RIGHT:
                      s.filledDirection = DOWN;
                      break;
                    case LEFT:
                      s.filledDirection = UP;
                      break;
                  }
                  break;
              }
              break;
          }
        }        

/*
        println("Segment: " + s.toString());
        println("lastFilledDirection: " + directionToString(lastFilledDirection));
        println("lastDirection: " + directionToString(lastDirection));
*/
        lastFilledDirection = s.filledDirection;
        lastDirection = s.getDirection();
      }
    }
  }
  
  String toString() {
    return toString(segments);
  }

  String toString(ArrayList<Segment> segments) {
    String line = "";
    for (Segment s : segments)
      line = line + s.toString() + "\n";
    return line;
  }
  
  void draw() {
    stroke(strokeColor);
    strokeWeight(4);
    
    for (Segment s : segments) {
      line(s.x0, s.y0, s.x1, s.y1);

/**/
      // Debug: Draw filledDirection markers
      switch (s.filledDirection) {
        case LEFT: line(s.x0, (s.y0+s.y1)/2, s.x0-10, (s.y0+s.y1)/2); break;
        case RIGHT: line(s.x0, (s.y0+s.y1)/2, s.x0+10, (s.y0+s.y1)/2); break;
        case UP: line((s.x0+s.x1)/2, s.y0, (s.x0+s.x1)/2, s.y0-10); break;
        case DOWN: line((s.x0+s.x1)/2, s.y0, (s.x0+s.x1)/2, s.y0+10); break;
      }
      
      // Debug: Draw direction markers
      switch (s.getDirection()) {
        case LEFT:
          line(s.x1, s.y1, s.x1+10, s.y1-10);
          line(s.x1, s.y1, s.x1+10, s.y1+10);
          break;
        case RIGHT:
          line(s.x1, s.y1, s.x1-10, s.y1-10);
          line(s.x1, s.y1, s.x1-10, s.y1+10);
          break;
        case UP:
          line(s.x1, s.y1, s.x1-10, s.y1+10);
          line(s.x1, s.y1, s.x1+10, s.y1+10);
          break;
        case DOWN:
          line(s.x1, s.y1, s.x1-10, s.y1-10);
          line(s.x1, s.y1, s.x1+10, s.y1-10);
          break;
      }
/**/
    }
  }
}

class Enemy {
  int x, x0, x1;
  int y, y0, y1;
  float alpha01;
  int w;
  int h;
  color background;
  PImage picture;
  
  // How many points are awarded when killing this enemy
  int worth;

  Enemy(int x, int y, String picture, color background, int worth) {
    x0 = x;
    y0 = y;
    x1 = round(random(100, width-100));
    y1 = round(random(100, height-100));
    alpha01 = 0;
    this.w = 130;
    this.h = 100;
    this.background = background;
    this.picture = loadImage(picture);
    this.picture.resize(w, h);
    this.worth = worth;
  }

  boolean touches(Path path) {
    if (pause)
      return false;
/*
    println("touches(): Enemy [", round(x - w/2), ", ", round(y - h/2), "] - [", round(x + w/2), ", ", round(y + h/2), "]");
*/
    for (Segment s : path.segments) {
      if (s.isHorizontal()) {
/*
        println(s.toString(), " is horizontal.");
*/
        boolean segmentYInsideEnemy = round(y - h/2) <= s.y0 && s.y0 <= round(y + h/2); 
        boolean segmentMinXInsideOrLeftEnemy = min(s.x0, s.x1) <= round(x + h/2);
        boolean segmentMaxXInsideOrRightEnemy = max(s.x0, s.x1) >= round(x - h/2);
/*
        println("segmentYInsideEnemy: ", segmentYInsideEnemy, ", segmentMinXInsideOrLeftEnemy: ", segmentMinXInsideOrLeftEnemy, ", segmentMaxXInsideOrRightEnemy: ", segmentMaxXInsideOrRightEnemy);
*/

        if (segmentYInsideEnemy && segmentMinXInsideOrLeftEnemy && segmentMaxXInsideOrRightEnemy) {
/*
          println("return true");
*/
          return true;
        }
      } else {
/*
        println(s.toString(), " is vertical.");
*/
        boolean segmentXInsideEnemy = round(x - w/2) <= s.x0 && s.x0 <= round(x + w/2); 
        boolean segmentMaxYInsideOrAboveEnemy = max(s.y0, s.y1) >= round(y - h/2);
        boolean segmentMinYInsideOrBelowEnemy = min(s.y0, s.y1) <= round(y + h/2);
/*
        println("segmentXInsideEnemy: ", segmentXInsideEnemy, ", segmentMaxYInsideOrAboveEnemy: ", segmentMaxYInsideOrAboveEnemy, ", segmentMinYInsideOrBelowEnemy: ", segmentMinYInsideOrBelowEnemy);
*/

        if (segmentXInsideEnemy && segmentMaxYInsideOrAboveEnemy && segmentMinYInsideOrBelowEnemy) {
/*
          println("return true");
*/
          return true;
        }
      }
    }
    return false;
  }

  void draw() {
    int oldX = x;
    int oldY = y;
    x = round((float)x0 * (1 - alpha01) + (float)x1 * alpha01);
    y = round((float)y0 * (1 - alpha01) + (float)y1 * alpha01);

    // Check if enemy killed the player
    if (cursor.excursionMode && touches(excursionPath)) {
      lives--;
      if (cursor.excursionMode) {
        cursor.setExcursionMode(false);
        if (excursionPath.segments.size() > 0) {
          cursor.x = excursionPath.segments.get(0).x0;
          cursor.y = excursionPath.segments.get(0).y0;
        }
        excursionPath = null;
      }
      if (lives == 0)
        gameOver = true;
        gameOverAccepted = false;
    }

    // Decide new target
    if (alpha01 > 1.0 || touches(borderPath)) {
/*
      // DEBUG: Swap points 0 & 1 to just reverse the path and ease debugging.
      int tmp;
      tmp = x0; x0 = x1; x1 = tmp;
      tmp = y0; y0 = y1; y1 = tmp;
*/

      x0 = oldX;
      y0 = oldY;
      x1 = round(random(100, width-100));
      y1 = round(random(100, height-100));
      x = x0;
      y = y0;

      alpha01 = 0;
    }

    stroke(#000000);
    strokeWeight(4);
    fill(background);
    rectMode(CENTER);
    rect(x, y, w, h);
    imageMode(CENTER);
    image(picture, x, y, w, h);

    stroke(#FF0000);
    line(x0, y0, x1, y1);

    if (!pause && !gameOver)
      alpha01 = alpha01 + 1.0 / (30.0 * 5.0);    
  }
}

String directionToString(int direction) {
  switch (direction) {
    case LEFT: return "LEFT";
    case RIGHT: return "RIGHT";
    case UP: return "UP";
    case DOWN: return "DOWN";
    default: return "<Unknown> ("+direction+")";
  }
}

int reverseDirection(int direction) {
  switch (direction) {
    case LEFT: return RIGHT;
    case RIGHT: return LEFT;
    case UP: return DOWN;
    case DOWN: return UP;
    default: return -1;
  }
}

float area(ArrayList<Segment> polygon) {
  // See: https://artofproblemsolving.com/wiki/index.php/Shoelace_Theorem
  float result = 0;
  for (int i = 0; i < polygon.size(); i++) {
    int iPlusOne = (i + 1) % polygon.size();
    result += (polygon.get(iPlusOne).x0+polygon.get(i).x0) * (polygon.get(iPlusOne).y0-polygon.get(i).y0); 
  }
  result = result / 2;
  return result;
}

ArrayList<Segment> sanitizeSegments(ArrayList<Segment> segments) {
  ArrayList<Segment> result = new ArrayList<Segment>();
  Segment lastSegment = segments.size()>0 ? segments.get(segments.size()-1) : null;

/*  
  println("sanitizeSegments():");
*/

  for (Segment s : segments) {
/*
    println("lastSegment: " + (lastSegment != null ? lastSegment.toString() : "null"));
    println("s: " + s.toString());
*/
    if (s.distance() > 0)
      if (lastSegment != null && lastSegment.getDirection() == s.getDirection()) {
        lastSegment.merge(s);
      } else {
        result.add(s);
        lastSegment = s;
      }
  }
  return result;
}

void updateMask() {
  PGraphics g = createGraphics(width, height);
  g.beginDraw();
  g.background(#000000);
  g.stroke(#FFFFFF);
  g.fill(#FFFFFF);
  g.beginShape();
  boolean first = true;
  for (Segment s : borderPath.segments) {
    if (first) {
      g.vertex(s.x0, s.y0);
      first = false;
    }
    g.vertex(s.x1, s.y1);
  }
  g.endShape(CLOSE);
  g.endDraw();
  filledImage = g.get();
  g = null;
  filledImage.loadPixels();
  maskImage.loadPixels();

  // FIXME: The maskImage can't be used "as is" to compute the initial count.
  // We end up with things like this: Freed: 1161779, Total: 943052
  maskFreedCount = 0;
  for (int i = 0; i < filledImage.pixels.length; i++) {
    if (filledImage.pixels[i] == #000000) {
      maskImage.pixels[i] = #00000000;
      maskFreedCount++;
    }
  }
  maskImage.updatePixels();
  
  if (maskInitialCount == 0)
    for (int i = 0; i < maskImage.pixels.length; i++)
      if (maskImage.pixels[i] == #00000000)
        maskInitialCount++;

  println("Freed: " + maskFreedCount + ", Total: " + maskInitialCount);
}

void newGame() {
  maskInitialCount = 0;
  maskFreedCount = 0;
  backgroundImage = loadImage("pics/chispa-01.jpg");
  backgroundImage.resize(width, height);
  maskImage = loadImage("pics/chispa-01-mask.png");
  maskImage.resize(width, height);
  borderPath = new Path(width, height);
  updateMask();
  excursionPath = null;
  cursor = new Cursor();
  enemies = new ArrayList<Enemy>();
  for (int i = 0; i < MAX_ENEMIES; i++) {
    Enemy e = new Enemy(round(random(100, width-100)), round(random(100, height-100)),
      "pics/block.png", color(round(random(100, 255)), round(random(100, 255)), round(random(100, 255))),
      1000);
    enemies.add(e);
  }
  lives = MAX_LIVES;
  score = 0;
  gameOver = false;
  gameOverAccepted = false;
}

void setup() {
  //fullScreen();
  size(1500,1000);
  frameRate(30);
  scoreFont = createFont("Arial", 16, true);
  newGame();
}

void draw() {
  // Background
  background(backgroundImage);
  
  // Mask
  imageMode(CORNERS);
  image(maskImage, 0, 0, width, height);

/*
  // Filled image
  imageMode(CORNERS);
  image(filledImage, 0, 0, width, height);
*/

  // Enemies
  for (Enemy e : enemies)
    e.draw();
  
  // Path
  borderPath.draw();
  
  // Excursion path
  if (excursionPath != null)
    excursionPath.draw();
  
  // Cursor
  cursor.draw();
  
  // Lives
  fill(#FFFFFF);
  textAlign(LEFT);
  textFont(scoreFont, 32);
  text("Lives: " + lives, 10, 40);
  
  // Score
  fill(#FFFFFF);
  textAlign(LEFT);
  textFont(scoreFont, 32);
  text("Score: " + score, 210, 40);

  // Freed count
  fill(#FFFFFF);
  textAlign(LEFT);
  textFont(scoreFont, 32);
  text("Freed: " + (float)maskFreedCount / (float)maskInitialCount, 410, 40);

  if (gameOver) {
    textAlign(CENTER);
    textFont(scoreFont, 128);
    text("GAME OVER!", width/2, height/2);
  }
}

void keyPressed() {
  if (gameOver) {
    // We don't want to auto-accept because the player just keeps pressing the move keys.
    if (gameOverAccepted)
      newGame();
  } else {
    if (key == CODED) {
      switch (keyCode) {
        case LEFT:
        case RIGHT:
        case UP:
        case DOWN:
          cursor.move(keyCode);
          break;
      }
    } else
      switch (key) {
        case ' ':
          cursor.setExcursionMode(true);
          excursionPath = new Path();
          break;
        case 'p':
          pause = !pause;
          if (pause)
            println("--- PAUSED ---");
          else
            println("--- UNPAUSED ---");
          break;
      }
  }
}

void keyReleased() {
  if (gameOver) {
    gameOverAccepted = true;
  } else {
    switch (key) {
      case ' ':
        if (cursor.excursionMode) {
          cursor.setExcursionMode(false);
          if (excursionPath.segments.size() > 0) {
            cursor.x = excursionPath.segments.get(0).x0;
            cursor.y = excursionPath.segments.get(0).y0;
          }
          excursionPath = null;
        }
        break;
    }
  }
}
