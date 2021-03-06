#if INERTIAL_NAV == ENABLED

/**
 * Inertial navigation system.
 *
 * Note that the accelerometers' x, y and z coordinate axes correspond
 * to North, East and Down, respectively, when the copter is facing
 * north. The ArduCopter navigation system uses the East, North, Up
 * system.
 *
 * Inertial x = Navigation y
 * Inertial y = Navigation x
 * Inertial z = - Navigation z
 */

/**
 * pos_error is the difference x_{real} - x_{est} where x_{real} is
 * the position received from an external positioning system and
 * x_{est} is the position estimated by inertial navigation.
 **/
Vector3f pos_error;
Vector3f vel_error;

static float KALMAN_L[] =  
{
  2.8461e-001,
  3.5955e-001,
  3.5671e-005,
  3.5671e-005,
   
  2.3470e-003,
  5.6380e-003,
  5.6145e-007,
  5.6145e-007
}; // Found using a MATLAB script

// Generates a new location and velocity in space based on inertia
// Calc 100 hz
void calc_inertia()
{
	// rotate accels based on DCM
	// --------------------------
	accels_rotated		= ahrs.get_dcm_matrix() * imu.get_accel();

	// ACC X POS = going North
	// ACC Y POS = going EAST
	// ACC Z POS = going DOWN

        // Temporary storage for the offset-corrected value of the moast recent
        // value from the accelerometers
        Vector3f corr_acc = accels_offset+accels_rotated;

        // Update position and velocity using trapezodial integration of the accelerometers
        accels_position    += (accels_velocity + (accels_acceleration + corr_acc / 2) * G_Dt / 3 * 100) * G_Dt;
        accels_velocity    += (accels_acceleration + corr_acc) * G_Dt / 2 * 100;
        accels_acceleration = corr_acc;
}

void inertial_error_correction(Vector3f current_pos, Vector3f current_vel) {
  
  pos_error = current_pos - accels_position;
  vel_error = current_vel - accels_velocity;
  
  accels_position      += pos_error * KALMAN_L[0];
  accels_velocity      += pos_error * KALMAN_L[1];
  accels_acceleration  += pos_error * KALMAN_L[2];
  accels_offset        += pos_error * KALMAN_L[3];
  
  accels_position      += vel_error * KALMAN_L[4];
  accels_velocity      += vel_error * KALMAN_L[5];
  accels_acceleration  += vel_error * KALMAN_L[6];
  accels_offset        += vel_error * KALMAN_L[7];
}

static void calibrate_accels()
{
	

    // Unknown purpose, maybe stabilize AHRS?
	for (int i = 0; i < 200; i++){
		delay(10);
		read_AHRS();
	}
	
	set_external_position_origin();

    // sets accels_velocity to 0,0,0
	zero_accels();
	accels_offset.zero();

	for (int i = 0; i < 100; i++){
		delay(G_Dt * 1000);
		read_AHRS();
		calc_inertia();
	}

    // Integrate 100*a for 100*G_dt => a = int/(100*G_Dt*1)
	accels_offset = -accels_velocity / (100 * G_Dt * 100);

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
  return get_ubisense_pos();
}
static inline void set_external_position_origin() {
  //set_ubisense_origin();
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
  g_gps->update();
  gps_origin_latitude = g_gps -> latitude;
  gps_origin_longitude = g_gps -> longitude;
  gps_origin_altitude = g_gps -> altitude;
}
//////////////////////////////////////////////////


//////////////////////////////////////////////////
// EXTERNAL POSITIONING SYSTEM: UbiSense

#define TMOTE_MAX_PWM 		1960.0
#define TMOTE_MIN_PWM 		1060.0
#define TMOTE_PWM_RANGE 	900.0

#define UBISENSE_MIN_XY 	-1000.0
#define UBISENSE_MAX_XY 	1000.0
#define UBISENSE_XY_RANGE 	2000.0

#define UBISENSE_MIN_Z 		0.0
#define UBISENSE_MAX_Z 		1000.0
#define UBISENSE_Z_RANGE 	1000.0

static const RC_Channel& UBISENSE_X_CHANNEL = g.rc_6;
static const RC_Channel& UBISENSE_Y_CHANNEL = g.rc_7;
static const RC_Channel& UBISENSE_Z_CHANNEL = g.rc_8;

static inline Vector3f get_ubisense_pos() {
  return Vector3f(
		  ((float)UBISENSE_Y_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_XY_RANGE + UBISENSE_MIN_XY,
		  ((float)UBISENSE_X_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_XY_RANGE + UBISENSE_MIN_XY,
		 -(((float)UBISENSE_Z_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_Z_RANGE + UBISENSE_MIN_Z)
		  );
}

static const RC_Channel& TARGET_X_CHANNEL = g.rc_1;
static const RC_Channel& TARGET_Y_CHANNEL = g.rc_2;
static const RC_Channel& TARGET_Z_CHANNEL = g.rc_4;

static inline Vector3f get_target_pos() {
  return Vector3f(
		  ((float)TARGET_Y_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_XY_RANGE + UBISENSE_MIN_XY,
		  ((float)TARGET_X_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_XY_RANGE + UBISENSE_MIN_XY,
		 -(((float)TARGET_Z_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_Z_RANGE + UBISENSE_MIN_Z)
		  );
}

static struct Location get_next_WP() {
	struct Location new_WP;
	Vector3f target_coord;
	target_coord = get_target_pos();
	
	new_WP.lng = target_coord.y;
	new_WP.lat = target_coord.x;
	new_WP.alt = -target_coord.z;

	return new_WP;
}

static inline Vector3f set_ubisense_origin() {
	// Do nothing
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
