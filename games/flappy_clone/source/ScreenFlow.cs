using UnityEngine;
using UnityEngine.UI;
using System.Collections;

public class ScreenFlow : MonoBehaviour {

  static ScreenFlow self; // singleton
  public GameObject[] screens;
  Animator animator;

  public void Awake() {
    if (self == null) {
      self = this;
      self.animator = GetComponent<Animator>();
      foreach (var screen in self.screens) {
        screen.transform.position = Vector3.zero;
        screen.SetActive(false);
      }
    } else Destroy(this);
  }

  public static void HideScreens() {
    foreach (var screen in self.screens) {
      screen.SetActive(false);
    }
  }

  public static bool isReady() {
    return self != null;
  }

  public static void SwitchTo(string name) {
    HideScreens();
    foreach (var s in self.screens) if (s.name == name) s.SetActive(true);
  }

  public static void GameOver() {
    self.animator.SetTrigger("GameOver");
  }

  public static void FirstFlap() {
    self.animator.SetTrigger("FirstFlap");
  }

}
