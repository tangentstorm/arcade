using System;
using UnityEngine;

public class GameWorld : MonoBehaviour {

  public static int score;

  private static GameWorld self; // singleton

  public BirdController bird;
  public GameObject scoreText;
  public GameObject pipes;

  private Vector3 startPos = Vector3.zero;

  public void Awake() {
    if (self == null) self = this; else Destroy(this);
  }

  public void Start() {
    self.startPos = bird.transform.position;
    score = 0;
  }

  // bird commands

  public static void DropBird() {
    self.bird.GetComponent<Rigidbody2D>().isKinematic = false;
  }

  public static void HoldBird() {
    self.bird.transform.position = self.startPos;
    self.bird.GetComponent<Rigidbody2D>().isKinematic = true;
  }

  public static void HideBird() {
    self.bird.gameObject.SetActive(false);
  }

  public static void ShowBird() {
    self.bird.gameObject.SetActive(true);
  }

  public static void Flap() {
    self.bird.Flap();
  }

  // pipe commands

  // !! These don't actually work because the pipe objects get cloned.
  //    I could just give them a tag and try to find them all and hide
  //    and show them, but the next thing on my list is to refactor the
  //    scrolling system so that scrolling is just a MonoBehaviour, and
  //    then it will be possible to deactivate entire layers.

  public static void HidePipes() {
    // TODO: self.pipes.SetActive(false);
  }

  public static void ShowPipes() {
    // TODO: self.pipes.SetActive(true);
  }

  // score commands

  public static void HideScore() {
	self.scoreText.SetActive(false);
  }
	
  public static void ShowScore() {
	self.scoreText.SetActive(true);
  }

}
