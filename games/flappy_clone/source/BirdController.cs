using UnityEngine;
using System.Collections;

public class BirdController : MonoBehaviour {

  public float flapForce = 5.0f;

  private Rigidbody2D body;
  private Animator anim;

  void Awake() {
    body = GetComponent<Rigidbody2D>();
    anim = GetComponent<Animator>();
  }

  void OnCollisionEnter2D(Collision2D c) {
    if (c.gameObject.tag == "ceil") { }
    else ScreenFlow.GameOver();
  }

  void OnTriggerExit2D(Collider2D c) {
    // if (c.gameObject.tag=="endZone")
    GameWorld.score += 10;
  }

  public void Flap() {
    anim.SetTrigger("flap");
    body.AddForce(Vector2.up * flapForce, ForceMode2D.Impulse);
  }

  void Update() {
    if (Input.GetButtonDown("Jump")) Flap();
  }

}
