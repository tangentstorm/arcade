using UnityEngine;
using System.Collections;

public class TitleState : StateMachineBehaviour {

  override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex) {
    GameWorld.HideBird();
	GameWorld.HidePipes();
    ScreenFlow.SwitchTo("TitleScreen");
  }

}
