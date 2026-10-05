using UnityEngine;
using UnityEngine.UI;
using System.Collections;

public class ScoreDisplay : MonoBehaviour {

  Text text;

  void Awake () {
    text = GetComponent<Text>(); 
  }

  void Update () {
     text.text = GameWorld.score.ToString();
  }
}
