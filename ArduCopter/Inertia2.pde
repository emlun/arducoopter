#if INERTIAL_NAV == ENABLED

/**
 * pos_error is the difference x_{real} - x_{est} where x_{real} is
 * the position received from an external positioning system and
 * x_{est} is the position estimated by inertial navigation.
 **/
Vector3f pos_error;

static float KALMAN_L[] =  
{
   0.15,
   0.11,
   0.00002,
   0.00002
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
  
  pos_error = get_external_position() - accels_position;
  
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

#define UBISENSE_MIN_X 		-500.0
#define UBISENSE_MAX_X 		500.0
#define UBISENSE_X_RANGE 	1000.0

#define UBISENSE_MIN_Y 		-500.0
#define UBISENSE_MAX_Y 		500.0
#define UBISENSE_Y_RANGE 	1000.0

static const RC_Channel& UBISENSE_X_CHANNEL = g.rc_6;
static const RC_Channel& UBISENSE_Y_CHANNEL = g.rc_7;

float ubisense_origin_x = 0;
float ubisense_origin_y = 0;

static inline Vector3f get_ubisense_pos() {
  return Vector3f(
		  ((float)UBISENSE_Y_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_Y_RANGE + UBISENSE_MIN_Y - ubisense_origin_y,
		  ((float)UBISENSE_X_CHANNEL.radio_in - TMOTE_MIN_PWM) / TMOTE_PWM_RANGE * UBISENSE_X_RANGE + UBISENSE_MIN_X - ubisense_origin_x,
		  -0
		  );
}

static inline Vector3f set_ubisense_origin() {
  Vector3f upos = get_ubisense_pos();
  ubisense_origin_x += upos.x;
  ubisense_origin_y += upos.y;
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
