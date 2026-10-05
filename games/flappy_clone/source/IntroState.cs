using UnityEngine;
using System.Collections;

public class IntroState : StateMachineBehaviour {

  override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex) {
    ScreenFlow.HideScreens();
    GameWorld.ShowBird();
    GameWorld.HoldBird();
    GameWorld.HidePipes();
	GameWorld.HideScore();
  }

  override public void OnStateUpdate(Animator animator, AnimatorStateInfo stateInfo, int layerIndex) {
    if (Input.GetButtonDown("Jump")) ScreenFlow.FirstFlap();
  }

}
