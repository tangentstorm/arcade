using UnityEngine;
using System.Collections;

public class GameOverState : StateMachineBehaviour {

  override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex) {
    Debug.Log("Entered GameOverState");
    GameWorld.HideBird();
    ScreenFlow.SwitchTo("GameOverScreen");
  }

}
