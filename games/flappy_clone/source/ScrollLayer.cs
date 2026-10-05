using UnityEngine;
using System;
using System.Collections.Generic;

[Serializable]
public class ScrollLayer {

  public GameObject gameObj;
  public float scrollFactor = 1f;
  public bool tileX;

  public float xSpacing = 100; // distance at which to space the items (usually the width of the object)
  private float xThresh = 0; // amount of movement required before re-arranging the clones.

  private float xCount = 0;
  private List<GameObject> clones = new List<GameObject>();

  public void Init() {
    clones.Add(gameObj);

    if (tileX) {
      xThresh = xSpacing / 2 * scrollFactor;
      // we will make 2 copies. items 0,1,2 = left, original, right
      for (int i=0; i<2; i++) clones.Add(GameObject.Instantiate(gameObj));
      clones[0].transform.position = (Vector2) clones[1].transform.position - new Vector2(xSpacing, 0f);
      clones[2].transform.position = (Vector2) clones[1].transform.position + new Vector2(xSpacing, 0f);
    }
  }

  public void ScrollBy(Vector2 amount) {

    Vector2 change = scrollFactor * amount;

    foreach (var c in clones) {
      c.transform.position = (Vector2) c.transform.position + change;
    }

    // repetition:
    xCount += change.x;
    if (tileX) {
      if (xCount < -xThresh) {
        clones[0].transform.position = clones[1].transform.position;
        clones[1].transform.position = clones[2].transform.position;
        clones[2].transform.position = (Vector2) clones[2].transform.position + new Vector2(xSpacing, 0);
        xCount += xSpacing;
      }
    }
  }

}
