#if INERTIAL_NAV == ENABLED

/**
 * pos_error is the difference x_{real} - x_{est} where x_{real} is
 * the position received from an external positioning system and
 * x_{est} is the position estimated by inertial navigation.
 **/
Vector3f pos_error;

float KALMAN_L[3] = {0.12, 0.06, 0.00001}; // Found using a MATLAB script

// generates a new location and velocity in space based on inertia
// Calc 100 hz
void calc_inertia()
{
	// rotate accels based on DCM
	// --------------------------
	accels_rotated		= ahrs.get_dcm_matrix() * imu.get_accel();
	accels_rotated		+= accels_offset;						// skew accels to account for long term error using calibration
	//accels_rotated.z 	+= 9.805;								// remove influence of gravity

	// rising 		= 2
	// neutral 		= 0
	// falling 		= -2


	// ACC Y POS = going EAST
	// ACC X POS = going North
	// ACC Z POS = going DOWN (lets flip this)


	// Integrate velocity to get the position
	// --------------------------------------

	Vector3f temp = accels_velocity * G_Dt;

	accels_position += temp;

	// Integrate accels to get the velocity
	// ------------------------------------
	temp = accels_rotated * (G_Dt * 100);
	//temp.z = -temp.z;
	// Temp is changed to world frame and we can use it normaly

	// Integrate accels to get the velocity
	// ------------------------------------
	accels_velocity			+= temp;

}

void inertial_error_correction() {
  pos_error = -accels_position;
  
  accels_position += pos_error * KALMAN_L[0];
  accels_velocity += pos_error * KALMAN_L[1];
  accels_offset += pos_error * KALMAN_L[2];
}

static void calibrate_accels()
{
	// sets accels_velocity to 0,0,0
	zero_accels();

	accels_offset.zero();

	for (int i = 0; i < 200; i++){
		delay(10);
		read_AHRS();
	}

	for (int i = 0; i < 100; i++){
		delay(10);
		read_AHRS();
		calc_inertia();
	}

	accels_offset = accels_velocity / 100;

	zero_accels();
	calc_inertia();

	Log_Write_Data(25, (float)accels_offset.x);
	Log_Write_Data(26, (float)accels_offset.y);
	Log_Write_Data(27, (float)accels_offset.z);
}

void zero_accels()
{
  accels_rotated.zero();
  accels_velocity.zero();
  accels_position.zero();
}


#endif
