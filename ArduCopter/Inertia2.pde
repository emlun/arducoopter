#if INERTIAL_NAV == ENABLED

/**
 * pos_error is the difference x_{real} - x_{est} where x_{real} is
 * the position received from an external positioning system and
 * x_{est} is the position estimated by inertial navigation.
 **/
Vector3f pos_error;

static float KALMAN_L[] =  
{
   0.1,
   0.05,
   0.0001,
   0.0001
}; // Found using a MATLAB script

// Generates a new location and velocity in space based on inertia
// Calc 100 hz
void calc_inertia()
{
	// rotate accels based on DCM
	// --------------------------
	accels_rotated		= ahrs.get_dcm_matrix() * imu.get_accel();

	// rising 		= 2
	// neutral 		= 0
	// falling 		= -2


	// ACC X POS = going North
	// ACC Y POS = going EAST
	// ACC Z POS = going DOWN (lets flip this)

        // Temporary storage for the offset-corrected value of the moast recent
        // value from the accelerometers
        Vector3f corr_acc = accels_offset+accels_rotated;

        // Update position and velocity using trapezodial integration of the accelerometers
        accels_position    += (accels_velocity + (accels_acceleration + corr_acc / 2) * G_Dt / 3 * 100) * G_Dt;
        accels_velocity    += (accels_acceleration + corr_acc) * G_Dt / 2 * 100;
        accels_acceleration = corr_acc;
}

void inertial_error_correction() {
  
  pos_error = get_external_position();
  
  pos_error -= accels_position;
  
  accels_position      += pos_error * KALMAN_L[0];
  accels_velocity      += pos_error * KALMAN_L[1];
  accels_acceleration  += pos_error * KALMAN_L[2];
  accels_offset        += pos_error * KALMAN_L[3];
}

static void calibrate_accels()
{
	

    // Unknown purpose, maybe stabilize AHRS?
	for (int i = 0; i < 200; i++){
		delay(10);
		read_AHRS();
	}
	
	g_gps->update();
	set_external_position_origin();

    // sets accels_velocity to 0,0,0
	zero_accels();
	accels_offset.zero();

	for (int i = 0; i < 100; i++){
		delay(G_Dt * 1000);
		read_AHRS();
		calc_inertia();
	}

    // Integrate 100*a for 500*G_dt => a = int/(100*G_Dt*1)
	accels_offset = -accels_velocity / (100 * G_Dt * 500);

	zero_accels();

	accels_position = get_external_position();

//	Log_Write_Data(25, (float)accels_offset.x);
//	Log_Write_Data(26, (float)accels_offset.y);
//	Log_Write_Data(27, (float)accels_offset.z);
}

/**
 * Returns the position of the craft as specified by an external
 * positioning system such as GPS.
 **/
static inline Vector3f get_external_position() {
  return gps_to_cartesian();
}
static inline void set_external_position_origin() {
  set_gps_origin();
}

//////////////////////////////////////////////////
// EXTERNAL POSITIONING SYSTEM: GPS
/**
 * gps_origin is set during calibration to the current position, and
 * all inertial navigation thereafter uses this position as the origin
 * of the local coordinate system.
 **/
long gps_origin_latitude;
long gps_origin_longitude;
long gps_origin_altitude;
static inline Vector3f gps_to_cartesian() {
  return Vector3f((float)(g_gps->latitude - gps_origin_latitude)*1.1, (float)(g_gps->longitude - gps_origin_longitude) * scaleLongDown * 1.1, -((float)g_gps->altitude - gps_origin_altitude));
}
static inline void set_gps_origin() {
  gps_origin_latitude = g_gps -> latitude;
  gps_origin_longitude = g_gps -> longitude;
  gps_origin_altitude = g_gps -> altitude;
}
//////////////////////////////////////////////////

void zero_accels()
{
  accels_rotated.zero();
  
  accels_position.zero();
  accels_velocity.zero();
  accels_acceleration.zero();
}


#endif