using UnityEngine;
using System.Collections;

public class rotation_S : MonoBehaviour {

    public float SpeedControl = 0.20f;
	// Update is called once per frame
	void Update () {
        transform.Rotate(0, SpeedControl, 0);
    }
}
