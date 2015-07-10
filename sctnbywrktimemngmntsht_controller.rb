##
# author:: VFA.HungLM
# since::  2013/12/03
# copyright:: Copyright 2013-2014 ABLEWORK Co.,Ltd All rights reserved.
##
class Work::SctnbywrktimemngmntshtController < ApplicationSrvsUsrController

  include Common::ClndrModule
  include Common::CmpnySelectCrudModule
  include Common::WrktimergstModule
  include Work::Common::WrktimemngmntshtModule

  public

  def get_list

    @use_blng_srch = use_blng_srch?
    @hash_pstn_id_main_sctn = Hash.new

    if @cndtn[:sctn_id].blank? then
      @usr.select_sctn_id = nil
    else
      @usr.select_sctn_id = @cndtn[:sctn_id].to_i
      @usr.select_usr_id = nil
    end
    init_cndtn_for_emply_list
    params[:page] = 1 if params[:page].blank?
    @cndtn[:page] = params[:page]

    if @usr.srvs_usr?(4, Cnst::PckgName::WORK) then
      @is_rcgnz_lv4_prmssn = true
    else
      @is_rcgnz_lv4_prmssn = false
    end

    sql_prmtr = {}
    sql_prmtr[:ebtm_ids] = []
    @usr.clear_cache
    init_prmr_sql_prmtr(sql_prmtr)
    sql_prmtr[:usr_ids] = get_rcgnzbl_usr_ids(true)
    sql_prmtr[:paginate] = false

    sql_prmtr[:shift2] = true
    @shift2 = true
    if !params.blank? && params["cndtn"] && params.has_key?("cndtn") then
      sql_prmtr[:sort_direction] = params[:cndtn][:sort_direction] 
      if params[:cndtn][:sort_item] == "emplymnt_cntrct_slp_code" || params[:cndtn][:sort_item] == "cntrct_seq_no" || 
         params[:cndtn][:sort_item] == "emply_code" || params[:cndtn][:sort_item] == "occptn_name" || 
         params[:cndtn][:sort_item] == "emplymnt_cntrctr_ots_name" then
           sql_prmtr[:sort_item] = params[:cndtn][:sort_item]
      end
    end

    @models = MEmply.get_emply_list(sql_prmtr)

    @models.each do |m|
      ecwtd = TEmplymntCntrctrWrkTimeMngmnt.get_emplymnt_cntrctr_wrk_time_dvsn(m[:usr_id], m[:ecm_id]) if m[:usr_id]
      if ecwtd == Dvsn::EmplymntCntrctrWrkTime::SFT_NOT_DDCT then
        sql_prmtr[:ebtm_ids] << m.ebtm_id
      end
      if m.main_blng_to_flg.to_i == 1 then
        @hash_pstn_id_main_sctn[m.emply_code] = m.pstn_id
      end

    end
    sql_prmtr[:paginate] = true
    if sql_prmtr[:ebtm_ids].count > 0 then
      @models = MEmply.get_emply_list(sql_prmtr)
    else
      @models = []
    end
    if !@is_rcgnz_lv4_prmssn && !@usr.srvs_usr?(3, Cnst::PckgName::WORK) then
      if sql_prmtr[:use_blng_srch] && (sql_prmtr[:blng] == Cnst::SctnBlng::TDY_MAIN_RCGNZ || sql_prmtr[:blng] == Cnst::SctnBlng::TDY_LST_MNTH_MAIN_RCGNZ) then
        blg = sql_prmtr[:blng]
      else
        blg = Cnst::SctnBlng::TDY_PST_MAIN_RCGNZ
      end
      reset_apply_end_day(blg)
      @models.delete_if{|m| check_delete_model(m, blg) }
      @models.each{|m|
        sql_prmtr[:ebtm_ids] << m.ebtm_id
      }
      sql_prmtr[:paginate] = true
      if sql_prmtr[:ebtm_ids].count > 0 then
        @models = MEmply.get_emply_list(sql_prmtr)
        reset_apply_end_day(blg)
      else
        @models = []
      end
    end
    last_month_start_day = MSctnDrctrusr.by_blng(Cnst::SctnBlng::TDY_MAIN_RCGNZ)
    @swtrs = MSctnWrkTimeRgstSystm.by_cmpny_id(@usr.select_cmpny_id, @usr.select_sctn_id)
    @cndtn[:redirect_page] ||= "sht"
  end

  def sht
    warn_msg_not_regist_wrk_strt_apply_time = "開始時刻が入力されていません。"
    warn_msg_not_regist_wrk_end_apply_time = "終了時刻が入力されていません。"
    warn_msg_not_regist_rst_apply_hrs = "休憩時間数が入力されていない または 0 時間です。"

    if @usr.srvs_usr?(4, Cnst::PckgName::WORK) then
      @is_rcgnz_lv4_prmssn = true
    else
      @is_rcgnz_lv4_prmssn = false
    end

    @enable_emply_move = true
    @cndtn[:select_day_from] ||= ""
    @cndtn[:select_day_to] ||= ""
    @cndtn[:low_rank_sctn] ||= ""

    @wrk_dcsn = Dvsn::WrkDcsn::CMPLT
    @wrk_dcsn_dsply = false
    @mntly_dsply = false
    @mntly_dsply = true if @usr.select_w == ""
    init_cndtn_for_emply_list
    sql_prmtr = {}
    init_prmr_sql_prmtr(sql_prmtr)
    setup_usr_select_ecm_id
    is_ok = setup_usr_select_ectm
    @swtrs = MSctnWrkTimeRgstSystm.by_cmpny_id(@usr.select_cmpny_id, @sctn_id)

    @emplymnt_cntrctr_wrk_time_dvsn = TEmplymntCntrctrWrkTimeMngmnt.get_emplymnt_cntrctr_wrk_time_dvsn(@usr.select_usr_id, @usr.select_ecm_id) if @usr.select_usr_id

    temp_swtrs ||= MSctnWrkTimeRgstSystm.by_cmpny_id(@usr.select_cmpny_id, @sctn_id)
    if temp_swtrs.paid_rst_dsply_flg == Flg::ON then
      @cndtn[:usr_id] = @usr.select_usr_id
      @cndtn[:cmpny_id] = @usr.select_cmpny_id
      @prms = setup_paid_rst_mngmnt
    end
   @models = [] if !is_ok
   return false if !is_ok
   @e = MEmply.find_by_usr_id(@usr.select_usr_id)
   @ebtm  = MEmplyBlngToMngmnt.find(:first, :select => "*",
                                    :conditions => ["emply_id = ? AND sctn_id = ? AND main_blng_to_flg = '1' AND  apply_strt_day <= ? AND apply_end_day >= ?",
                                                    @e.id,
                                                    @usr.select_sctn_id,
                                                    @usr.select_mnth_str_end_day[1],
                                                    @usr.select_mnth_str_end_day[1]])
   @ebtm  ||= MEmplyBlngToMngmnt.find(:first, :select => "*",
                                      :conditions => ["emply_id = ? AND sctn_id = ? AND main_blng_to_flg = '1' AND  apply_strt_day <= ? AND apply_end_day >= ?",
                                                    @e.id,
                                                    @usr.select_sctn_id,
                                                    @usr.select_mnth_str_end_day[0],
                                                    @usr.select_mnth_str_end_day[0]])
   @ebtm  ||= MEmplyBlngToMngmnt.find(:first, :select => "*",
                                      :conditions => ["emply_id = ? AND sctn_id = ? AND main_blng_to_flg = '1' AND  apply_strt_day >= ? AND apply_end_day <= ?",
                                                 @e.id,
                                                 @usr.select_sctn_id,
                                                 @usr.select_mnth_str_end_day[0],
                                                 @usr.select_mnth_str_end_day[1]])
    main_ebtm = MEmplyBlngToMngmnt.find(:first, :select => "*",
                                      :conditions => ["emply_id = ? AND main_blng_to_flg = '1'",
                                                 @e.id],
                                      :order => "apply_strt_day desc")
    @main_sctn_id = main_ebtm.sctn_id if main_ebtm

    main_blng_to_flg = Flg::OFF
    main_blng_to_flg = Flg::ON if @ebtm
    @wrk_dcsn_dsply  = true if @swtrs.wrk_dcsn_use_flg == Flg::ON

    c  = "m_clndr"
    cc = "#{@usr.cntrct_schm}.m_cmpny_clndr"
    sc = "#{@usr.cntrct_schm}.m_sctn_clndr"
    s  = "#{@usr.cntrct_schm}.m_sctn"
    emp  = "#{@usr.cntrct_schm}.m_emply"
    ebtm = "#{@usr.cntrct_schm}.m_emply_blng_to_mngmnt"
    wtms = "#{@usr.cntrct_schm}.t_wrk_time_mngmnt_sht"
    sbt  = "#{@usr.cntrct_schm}.t_sctn_by_timecrd"

    find_params = get_sht_find_params()
    find_params[:select] ||=

        "'' AS paid_rst_trnsfr_out_time_wrk_hrs_orgnl, " +
        "#{c}.id AS clndr_id, " +
        "#{c}.day AS wrk_day, " +
        "#{c}.hldy_name AS hldy_name, " +
        "#{c}.weekday_name AS weekday_name, " +
        "#{c}.pblc_hldy_flg AS pblc_hldy_flg, " +
        "#{c}.weekday_dvsn AS weekday_dvsn, " +
        "'' AS wrk_time_stts, " +

        "#{emp}.hrly_wage_unt_prc AS emp_hrly_wage_unt_prc, " +
        "#{emp}.id AS emply_id, " +

        "#{ebtm}.sctn_id AS ebtm_sctn_id, " +

        "#{cc}.hlydy_dvsn AS hlydy_dvsn, " +
        "#{cc}.evnt_name AS evnt_name, " +

        "#{sc}.hlydy_dvsn AS sctn_hlydy_dvsn, " +
        "#{sc}.evnt_name AS sctn_evnt_name, " +

        "#{s}.sctn_code AS sctn_code, " +
        "#{s}.sctn_omttd_name AS sctn_omttd_name, " +

        "#{wtms}.*, " +
        "#{wtms}.id AS wtms_id, " +
        "'' AS mdngt_wrk_hrs, " +
        "'' AS mdngt_out_time_wrk_hrs, " +
        "'' AS out_time_wrk_apply_hrs, " +
        "'' AS paid_rst_days, " +
        "'' AS paid_rst_trnsfr_days, " +
        "'' AS chngd_rst_days, " +
        "'' AS rcgnz_stts_dvsn_, " +
        "'' AS cmplt_stts_dvsn_, " +
        "'' AS wrk_stts_dvsn, " +

        "'' AS r_wtmu, " +

        "'' AS rst_time_rcrd_smry, " +
        "'' AS rst_time_smry, " +

        "'' AS ram_id, " +
        "'' AS ram_rst_strt_day, " +
        "'' AS ram_rst_end_day, " +
        "'' AS ram_rst_strt_time, " +
        "'' AS ram_rst_end_time, " +
        "'' AS ram_rst_rsn, " +
        "'' AS ram_apply_cncl_flg, " +
        "'' AS ram_smry, " +
        "'' AS ram_rcrd_is_list, " +
        "'' AS ram_rcgnz_stts, " +
        "'' AS ram_rcgnz_stts_dvsn, " +
        "'' AS warn_msg, " +
        "'false' AS cmplt_err, " +
        "'' AS is_trnsfr_rst, " +

        "'' AS rd_rst_dvsn_name, " +
        "'' AS rd_paid_flg, " +
        "'' AS rd_rd_prt_rst_flg, " +

        "'' AS otwam_id, " +
        "'' AS otwam_apply_day, " +
        "'' AS otwam_apply_cncl_flg, " +
        "'' AS otwam_strt_time, " +
        "'' AS otwam_end_time, " +
        "'' AS otwam_apply_rsn, " +
        "'' AS otwam_rcgnz_stts_dvsn, " +
        "'' AS otwam_rcgnz_usr_id, " +
        "'' AS otwam_rcgnz_day, " +
        "'' AS otwam_rcgnz_rsn, " +
        "'' AS otwam_out_time_wrk_rsn, " +
        "'' AS otwam_smry, " +
        "'' AS otwam_rcrd_is_list, " +
        "'' AS otwam_rcgnz_stts, " +
        "'' AS otwam_wrk_lwr_bnd, " +
        "'' AS otwam_wrk_uppr_bnd, " +
        "'' AS otwam_warn_msg, " +
        "'false' AS otwam_cmplt_err, " +
        "'' AS frst_outtimewrk_strt_time, " +
        "'' AS lst_outtimewrk_end_time, " +
        "'' AS outtimewrk_rst_hrs, " +
        "'' AS ttl_spply_mny, " +
        "'' AS otwam_ids, " +
        "'' AS otwam_strt_times, " +
        "'' AS otwam_end_times, " +
        "'' AS otwam_apply_rsns, " +
        "'' AS otwam_rcgnz_stts_dvsns, " +
        "'' AS otwam_rcgnz_usr_ids, " +

        "'' AS otwd_out_time_wrk_dvsn_name, " +

        "'' AS gng_to_offc_time, " +
        "'' AS leave_offc_time, " +
        "'' AS late_lvng_erly_hrs, " +
        "'' AS late_lvng_erly_ddctn_hrs, " +
        "'' AS late_lvng_erly_gng_to_offc_time, " +
        "'' AS late_lvng_erly_leave_offc_time, " +
        "'' AS late_lvng_erly_rst_not_take_flg, " +
        "'' AS late_lvng_erly_rst_not_take_time, " +
        "'' AS late_lvng_erly_smry, " +
        "'' AS late_lvng_erly_rcrd_is_list, " +
        "'' AS late_lvng_erly_rcgnz_stts, " +
        "'' AS late_lvng_erly_rcgnz_stts_dvsn, " +
        "'' AS late_lvng_erly_warn_msg, " +
        "'false' AS late_lvng_erly_cmplt_err, " +

        "'' AS drct_go_rtrn_bsnss_trip_rsn, " +
        "'' AS drct_go_rtrn_bsnss_trip_smry, " +
        "'' AS drct_go_rtrn_bsnss_trip_day_num, " +
        "'' AS drct_go_rtrn_bsnss_trip_wrk_strt_time, " +
        "'' AS drct_go_rtrn_bsnss_trip_wrk_end_time, " +
        "'' AS drct_go_rtrn_bsnss_trip_rcrd_is_list, " +
        "'' AS drct_go_rtrn_bsnss_trip_rcgnz_stts, " +
        "'' AS drct_go_rtrn_bsnss_trip_rcgnz_stts_dvsn, " +
        "'' AS drct_go_rtrn_bsnss_trip_warn_msg, " +
        "'false' AS drct_go_rtrn_bsnss_trip_cmplt_err, " +

        "#{sbt}.*, " +
        "'' AS swtrs_mdnght_wrk_exc_flg, " +
        "'' AS swtrs_late_calc_prcssng_dvsn, " +
        "'' AS swtrs_smpl_calc_absnc_calc_flg, " +
        "'' AS swtrs_smpl_calc_aftr_outtimewrk_late_offset_flg, " +
        "'' AS swtrs_smpl_calc_bfr_outtimewrk_late_offset_flg, " +
        "'' AS swtrs_smpl_calc_inpt_rcgnz_usr_flg, " +
        "'' AS swtrs_smpl_calc_outtimewrk_late_calc_dvsn, " +
        "'' AS swtrs_smpl_calc_prt_rst_rstshrt_calc_flg, " +
        "'' AS swtrs_smpl_calc_wrktime_dvsn, " +
        "'' AS swtrs_smpl_calc_rst_day_wrktime_dvsn, " +
        "'' AS swtrs_smpl_calc_wrktime_spplmnttn_dvsn, " +
        "'' AS swtrs_smpl_calc_mdnght_wrk_spplmnttn_dvsn, " +
        "'' AS swtrs_mdnght_wrk_jdgmnt_time, " +
        "'' AS swtrs_mdnght_wrk_day_chng_time, " +
        "'' AS swtrs_smpl_calc_in_outtimewrk_late_offset_flg, " +
        "'' AS swtrs_wrk_sht_dtl_rst_input_dsply_flg, " +
        "'' AS swtrs_wrk_sht_mdnght_wrk_dsply_flg, " +
        "'' AS swtru_mini_flx_late_pstpnmnt_time, " +

        "'' AS bfr_wrk_strt_time, " +
        "'' AS bfr_wrk_end_time, " +
        "'' AS aftr_wrk_strt_time, " +
        "'' AS aftr_wrk_end_time, " +

        "'' AS not_employee, " +
        "'' AS rstday_wrk, " +

        "'' AS warn_msg_wrk_strt_rcrd_time, " +
        "'' AS warn_msg_wrk_end_rcrd_time, " +
        "'' AS warn_msg_wrk_strt_apply_time, " +
        "'' AS warn_msg_wrk_end_apply_time, " +
        "'' AS warn_msg_rst_apply_hrs, " +
        "'' AS warn_msg_wrk_apply_hrs, " +
        "'' AS warn_msg_wrk_strt_time, " +
        "'' AS warn_msg_wrk_end_time, " +
        "'' AS warn_msg_wrk_hrs, " +
        "'' AS warn_msg_out_time_wrk_hrs, " +
        "'' AS warn_msg_paid_rst_hrs, " +
        "'' AS warn_msg_paid_rst_days, " +
        "false AS is_warn_ram_smry, " +
        "'' AS disabled, " +
        "'' AS erly_out_time_wrk_disabled, " +
        "'' AS out_time_wrk_disabled, " +
        "'' AS rst_wrk_disabled, " +
        "'' AS label_disabled, " +
        "'' AS bsnss_trip_disabled, " +
        "'' AS drct_go_disabled, " +
        "'' AS drct_rtrn_disabled, " +
        "'' AS late_disabled, " +
        "'' AS lvng_erly_disabled, " +
        "'' AS emplymnt_cntrctr_wrk_time_dvsn, " +
        "'' AS out_of_term "

    str_join_ebtm_sctn_id = ""
    str_join_ebtm_sctn_id = "#{ebtm}.sctn_id = #{@usr.select_sctn_id} AND " unless main_blng_to_flg == Flg::ON

    find_params[:joins] ||=
        "LEFT OUTER JOIN #{cc} ON " +
        "#{cc}.clndr_id = #{c}.id AND " +
        "#{cc}.cmpny_id = #{@usr.select_cmpny_id} AND " +
        "#{cc}.deleted_at IS NULL " +

        "LEFT OUTER JOIN #{emp} ON " +
        "#{emp}.usr_id = #{@usr.select_usr_id} AND " +
        "#{emp}.emply_dvsn = '#{Dvsn::Emply::EMPLY}' AND " +
        "#{emp}.deleted_at IS NULL " +

        "LEFT OUTER JOIN #{ebtm} ON " +
        "#{emp}.id = #{ebtm}.emply_id AND " +
        "#{c}.day between #{ebtm}.apply_strt_day AND #{ebtm}.apply_end_day AND " +
        "#{ebtm}.main_blng_to_flg = #{main_blng_to_flg} AND " +
        str_join_ebtm_sctn_id +
        "#{ebtm}.rcgnz_dvsn = #{Dvsn::Rcgnz::RCGNZ} AND " +
        "#{ebtm}.deleted_at IS NULL " +

        "LEFT OUTER JOIN #{sc} ON " +
        "#{sc}.clndr_id = #{c}.id AND " +
        "#{sc}.sctn_id = #{ebtm}.sctn_id AND " +
        "#{sc}.deleted_at IS NULL " +

        "LEFT OUTER JOIN #{s} ON " +
        "#{s}.id = #{ebtm}.sctn_id AND " +
        "#{s}.deleted_at IS NULL " +

        "LEFT OUTER JOIN #{wtms} ON " +
        "#{wtms}.wrk_day_clndr_id = #{c}.id AND " +
        "#{wtms}.deleted_at IS NULL AND " +
        "(#{wtms}.usr_id IS NULL or #{wtms}.usr_id = #{@usr.select_usr_id}) AND " +
        "(#{wtms}.sctn_id IS NULL or #{wtms}.sctn_id = #{ebtm}.sctn_id) AND " +
        "#{wtms}.emplymnt_cntrct_mngmnt_id = #{@usr.select_ecm_id} " +

        "LEFT OUTER JOIN #{sbt} ON " +
        "#{sbt}.wrk_day_clndr_id = #{c}.id AND " +
        "#{sbt}.deleted_at IS NULL AND " +
        "(#{sbt}.usr_id IS NULL or #{sbt}.usr_id = #{@usr.select_usr_id}) AND " +
        "(#{sbt}.sctn_id is NULL or #{sbt}.sctn_id = #{ebtm}.sctn_id)"

    find_params[:conditions] ||= ["#{c}.day between ? AND ? ", *@usr.select_mnth_day_rng]
    find_params[:order] ||= "day"

    @models = MClndr.find(
      :all,
      :select => find_params[:select],
      :joins => find_params[:joins],
      :conditions => find_params[:conditions],
      :order => find_params[:order])

    @sm_rst_apply_hrs = 0
    @sm_rst_rcrd_hrs = 0

    @models.each{|i|
      i.rst_wrk_disabled = false
      i.disabled = false
      i.label_disabled = false

      i.rst_wrk_disabled = TSctnByTimecrd.disabled_wrk_dcsn_dvsn?(i.wrk_dcsn_dvsn)

      i.disabled = true if i.ebtm_sctn_id.to_i != @sctn_id.to_i

      @wrk_dcsn = Dvsn::WrkDcsn::NON  if i.wrk_dcsn_dvsn != Dvsn::WrkDcsn::CMPLT && !i.disabled

      wtmsl = MWrkTimeMngmntShtLbl.by_id(i.wrk_time_mngmnt_sht_lbl_id.to_i)
      i.label_disabled = true if wtmsl && wtmsl.rst_dvsn_id && wtmsl.rst_dvsn_id != "" && i.wrk_strt_apply_time.blank? && i.wrk_end_apply_time.blank? && i.rst_apply_hrs.blank?
      #set label from main timcard
      if main_blng_to_flg == Flg::OFF then
        wtms_label = TWrkTimeMngmntSht.find(
                                            :first,
                                            :select => "*, 'TWrkTimeMngmntSht::find_wts_label' as for_tuning",
                                            :conditions => ["usr_id = ? and sctn_id = ? and wrk_day_clndr_id = ? and emplymnt_cntrct_mngmnt_id = ? and deleted_at is null", 
                                                           @usr.select_usr_id, @main_sctn_id, i.clndr_id,@usr.select_ecm_id])
        i.wrk_time_mngmnt_sht_lbl_id = wtms_label.wrk_time_mngmnt_sht_lbl_id if wtms_label
        i.rcgnz_stts_dvsn = wtms_label.rcgnz_stts_dvsn if wtms_label
      end
      next unless before_mdl_add2sht(i)
      take_in_rgst_data_sctn_by_timecrd(i)
      i.wrk_day_clndr_id = i[:clndr_id]
      @is_not_cmplt = true if i.cmplt_stts_dvsn != Dvsn::CmpltStts::CMPLT && i.out_of_term == false
      @has_enabled  = true if i.disabled == false && i.out_of_term == false

      @sm_rst_apply_hrs += i.rst_apply_hrs.to_f unless i.rst_apply_hrs.blank?
      @sm_rst_rcrd_hrs += i.rst_rcrd_hrs.to_f unless i.rst_rcrd_hrs.blank?

      @sm_rst_apply_hrs = adjst_hour(@sm_rst_apply_hrs)
      @sm_rst_rcrd_hrs = adjst_hour(@sm_rst_rcrd_hrs)

      i.rst_rcrd_hrs = hour_to_time(i.rst_rcrd_hrs)
      i.rst_apply_hrs = hour_to_time(i.rst_apply_hrs)
      i.late_hrs = hour_to_time(i.late_hrs)
      i.absnc_hrs = hour_to_time(i.absnc_hrs)
      i.paid_rst_hrs = hour_to_time(i.paid_rst_hrs)
      i.trnsfr_rst_hrs = hour_to_time(i.trnsfr_rst_hrs)
      i.chngd_rst_hrs = hour_to_time(i.chngd_rst_hrs)
      i.out_time_wrk_hrs = hour_to_time(i.out_time_wrk_hrs)
      i.excss_dfcncy_wrk_hrs = hour_to_time(i.excss_dfcncy_wrk_hrs)
      i.paid_rst_trnsfr_out_time_wrk_hrs = hour_to_time(i.paid_rst_trnsfr_out_time_wrk_hrs)
      i.paid_rst_chngd_out_time_wrk_hrs = hour_to_time(i.paid_rst_chngd_out_time_wrk_hrs)

      i.warn_msg_wrk_strt_apply_time = warn_msg_not_regist_wrk_strt_apply_time if (i.wrk_strt_rcrd_time.blank? == false || i.wrk_end_rcrd_time.blank? == false || i.wrk_end_apply_time.blank?  == false) && i.wrk_strt_apply_time.blank?
      i.warn_msg_wrk_end_apply_time  = warn_msg_not_regist_wrk_end_apply_time  if (i.wrk_strt_rcrd_time.blank? == false || i.wrk_end_rcrd_time.blank? == false || i.wrk_strt_apply_time.blank? == false) && i.wrk_end_apply_time.blank?
      i.warn_msg_rst_apply_hrs = warn_msg_not_regist_rst_apply_hrs if (i.wrk_strt_apply_time.blank? == false || i.wrk_end_apply_time.blank? == false) && i.rst_apply_hrs.blank?
    }
    @sm_rst_apply_hrs = hour_to_time(@sm_rst_apply_hrs)
    @sm_rst_rcrd_hrs = hour_to_time(@sm_rst_rcrd_hrs)
    fix_page_num
    sql_prmtr[:page] = @cndtn[:page]
    sql_prmtr[:shift2] = true
    get_pager_emply_ids(sql_prmtr)
    init_link_cndtn
  end

  def update
    @arr_models = []
    @usr.select_usr_id = params[:cndtn][:select_usr_id].to_i if params[:cndtn] && params[:cndtn][:select_usr_id]
    @usr.select_ebtm_id = params[:cndtn][:select_ebtm_id].to_i if params[:cndtn] && params[:cndtn][:select_ebtm_id]
    @usr.select_ecm_id = params[:cndtn][:select_ecm_id].to_i if params[:cndtn] && params[:cndtn][:select_ecm_id]
    @usr.select_sctn_id = params[:cndtn][:select_sctn_id].to_i if params[:cndtn] && params[:cndtn][:select_sctn_id]
    @usr.select_cmpny_id = params[:cndtn][:select_cmpny_id].to_i if params[:cndtn] && params[:cndtn][:select_cmpny_id]
    ActiveRecord::Base::transaction() do
      unless params[:model] then
        redirect_to :action => "sht"
        return
      end
      params[:model] = params[:model].sort_by{|key,value| value[:wrk_day_clndr_id]}
      params[:model].each{|index, v|

        v[:rst_rcrd_hrs] = time_to_hour(v[:rst_rcrd_hrs]) if v[:rst_rcrd_hrs]
        v[:rst_apply_hrs] = time_to_hour(v[:rst_apply_hrs]) if v[:rst_apply_hrs]
        v[:late_hrs] = time_to_hour(v[:late_hrs]) if v[:late_hrs]
        v[:absnc_hrs] = time_to_hour(v[:absnc_hrs]) if v[:absnc_hrs]
        v[:paid_rst_hrs] = time_to_hour(v[:paid_rst_hrs]) if v[:paid_rst_hrs]
        v[:trnsfr_rst_hrs] = time_to_hour(v[:trnsfr_rst_hrs]) if v[:trnsfr_rst_hrs]
        v[:chngd_rst_hrs] = time_to_hour(v[:chngd_rst_hrs]) if v[:chngd_rst_hrs]
        v[:out_time_wrk_hrs] = time_to_hour(v[:out_time_wrk_hrs]) if v[:out_time_wrk_hrs]
        v[:excss_dfcncy_wrk_hrs] = time_to_hour(v[:excss_dfcncy_wrk_hrs]) if v[:excss_dfcncy_wrk_hrs]
        v[:paid_rst_trnsfr_out_time_wrk_hrs] = time_to_hour(v[:paid_rst_trnsfr_out_time_wrk_hrs]) if v[:paid_rst_trnsfr_out_time_wrk_hrs]
        v[:paid_rst_chngd_out_time_wrk_hrs] = time_to_hour(v[:paid_rst_chngd_out_time_wrk_hrs]) if v[:paid_rst_chngd_out_time_wrk_hrs]

        @model = model_class.find_by_id_or_new(v[:id].to_i, v[:usr_id].to_i, v[:wrk_day_clndr_id].to_i, v[:sctn_id].to_i)
        @model.attributes = strip_hash(v)
        @arr_models << @model
        unless @model.save then
          break
        end
      }

      if @model && !@model.errors.empty? then
          sht
          render :action => "sht"
          raise ActiveRecord::Rollback
          return false
      end

      after_update

      if @model && !@model.errors.empty? then
          sht
          render :action => "sht"
          raise ActiveRecord::Rollback
          return false
      end

      if @model then
        flash[:notice] = "更新しました。"
      else
        flash[:warning] = "更新できません。"
      end

      redirect_to :action => "sht"
    end

  end

  protected

  def after_update
    params[:model_sht].each{|index, v|
      if v[:wrk_time_mngmnt_sht_lbl_id] && v[:wtms_id] then
        if v[:wtms_id].to_i > 0 then
          twtms = TWrkTimeMngmntSht.find(:first, :conditions => {:id => v[:wtms_id], :deleted_at => nil})
          if twtms then
            wtmsl_old = MWrkTimeMngmntShtLbl.by_id(twtms.wrk_time_mngmnt_sht_lbl_id)
          end
        end
        old_wrk_day_clndr_id = v[:wrk_day_clndr_id]
        if v[:trgt_usr_id] then
          trgt_usr_id = v[:trgt_usr_id]
        end

        wtms = TWrkTimeMngmntSht.find_by_key_or_new(v[:trgt_usr_id].to_i, v[:emplymnt_cntrct_mngmnt_id].to_i, v[:ebtm_sctn_id].to_i, v[:wrk_day_clndr_id].to_i, 0, true)

        v.delete("wtms_id")
        v.delete("trgt_usr_id")
        v.delete("ebtm_sctn_id")
        wtms.attributes = strip_hash(v)
        unless wtms.save && update_sub_section_label(wtms,v) then
          break
        else
          v[:old_wrk_day_clndr_id] = old_wrk_day_clndr_id
          if wtmsl_old && wtmsl_old.rst_dvsn_id && v[:wrk_time_mngmnt_sht_lbl_id] && (wtmsl_old.id.to_i != v[:wrk_time_mngmnt_sht_lbl_id].to_i) then
            with_draw_rst_frm(v,trgt_usr_id)
          end
          if v[:wrk_time_mngmnt_sht_lbl_id].to_i > 0 then
            if (wtmsl_old && (wtmsl_old.id.to_i != v[:wrk_time_mngmnt_sht_lbl_id].to_i)) || (!wtmsl_old && v[:wrk_time_mngmnt_sht_lbl_id].to_i > 0) then
              wtmsl_n = MWrkTimeMngmntShtLbl.by_id(v[:wrk_time_mngmnt_sht_lbl_id])
              if wtmsl_n.rst_dvsn_id then
                trgt_usr_id ||= nil
                unless check_data_in_timecard_input_rested_frm_and_rest_day_remain(index,v, wtmsl_n.rst_dvsn_id, trgt_usr_id, sts_sub_timecard_all_time_is_nil) then
                  # save change model
                  if !v[:wrk_time_mngmnt_sht_lbl_id].blank? then
                    @arr_model_sht.push(v[:wrk_day_clndr_id])
                  end
                end
              end
            end
          end
          if v[:old_wrk_day_clndr_id] then
            v.delete("old_wrk_day_clndr_id")
          end
        end
      end
    }
  end

  def update_sub_section_label(model, v)
   @e ||= MEmply.find_by_usr_id(model[:usr_id].to_i)
   @ebtm ||= MEmplyBlngToMngmnt.find(:all, :select => "*",
                                     :conditions => ["emply_id = ? AND main_blng_to_flg = '0' AND apply_strt_day <= ? AND apply_end_day >= ?",
                                                     @e.id,
                                                     ApplicationHelper.today,
                                                     ApplicationHelper.today])
    @ebtm.each do |eb|
      wtms = TWrkTimeMngmntSht.find_by_key_or_new(model[:usr_id].to_i, model[:emplymnt_cntrct_mngmnt_id].to_i, eb.sctn_id, model[:wrk_day_clndr_id].to_i, 0, true)
      wtms.attributes = strip_hash(v)
      unless wtms.save then
        return false
      end
    end
    return true
  end

  def model_class
    TSctnByTimecrd
  end

  def check_data_in_timecard_input_rested_frm_and_rest_day_remain(index, model, rst_dvsn_id, trgt_usr_id = nil)
    if @arr_models[index.to_i][:wrk_strt_apply_time].blank? && @arr_models[index.to_i][:wrk_end_apply_time].blank? && @arr_models[index.to_i][:rst_apply_hrs].blank? then
      apply_rst_frm(model, rst_dvsn_id, trgt_usr_id)
    else
      @model.errors.add_to_base("タイムカードに勤務時間（開始・終了・休憩）が入力されているため、休暇が申請できませんでした。\n休暇ラベルを選択している場合は、勤務時間（開始・終了・休憩）を空欄にしてください。")
      return false
    end
  end

  def get_pager_emply_ids(sql_prmtr)
    @cndtn[:page_inc_usr_id] = ""
    @cndtn[:page_dec_usr_id] = ""
    @prev_usr_id = ""
    @next_usr_id = ""
    @prev_sctn_id = ""
    @next_sctn_id = ""
    @prev_ebtm_id = ""
    @next_ebtm_id = ""
    @prev_slp_code = ""
    @next_slp_code = ""
    @cur_usr_name = ""
    @prev_usr_name = ""
    @next_usr_name = ""
    max_name_length = 20
    mebtm_id = @usr.select_ebtm_id
    begin
      u_sctn_id = MEmplyBlngToMngmnt.find(mebtm_id).sctn_id
      @usr.select_sctn_id = u_sctn_id
      @cndtn[:select_ebtm_id] = mebtm_id
    rescue
      u_sctn_id = nil
    end
    if @enable_emply_move then
      cnt_idx = 0
      cur_usr_idx = 0
      cur_usr_ids = []
      ary_emply = []
      if params[:sctn_id] && session[:o_page] then
        if params[:ac] == "next" && session[:t_next] == "false" then
          @cndtn[:page] = session[:o_page] + 1
          sql_prmtr[:page] = @cndtn[:page]
        elsif params[:ac] == "prev" && session[:t_prev] == "false" then
          @cndtn[:page] = session[:o_page] - 1
          sql_prmtr[:page] = @cndtn[:page]
        else
          @cndtn[:page] = session[:o_page]
          sql_prmtr[:page] = @cndtn[:page]
        end
        session[:o_page] = nil
        session[:t_next] = nil
        session[:t_prev] = nil
      end

      rs_emply = []
      if sql_prmtr[:shift2] == true then
        rs_emply_all = MEmply.get_emply_list(sql_prmtr)
        rs_emply_all.each do |m|
          ecwtd = TEmplymntCntrctrWrkTimeMngmnt.get_emplymnt_cntrctr_wrk_time_dvsn(m[:usr_id], m[:ecm_id]) if m[:usr_id]
          if ecwtd == Dvsn::EmplymntCntrctrWrkTime::SFT_NOT_DDCT then
            rs_emply << m
          end
        end
      else
        rs_emply = MEmply.get_emply_list(sql_prmtr)
      end

      if rs_emply && rs_emply.length > 0 then
      # p "[get_pager_emply_ids] rs_emply.length = #{rs_emply.length}" if @debug_prt
        rs_emply.each do |r_emply|
          cur_usr_ids << r_emply.usr_id
          ary_emply << r_emply
          if params[:sctn_id] then  # We got it from time card screen
            n_cndtn = ("#{r_emply.usr_id}" == "#{@usr.select_usr_id}") && ("#{r_emply.sctn_id}" == "#{params[:sctn_id]}")
          elsif u_sctn_id
            n_cndtn = ("#{r_emply.usr_id}" == "#{@usr.select_usr_id}") && ("#{r_emply.sctn_id}" == "#{u_sctn_id}")
          else
            n_cndtn = "#{r_emply.usr_id}" == "#{@usr.select_usr_id}"
          end
          if n_cndtn then
          # p "[get_pager_emply_ids] H I T : #{@usr.select_usr_id} == #{r_emply.usr_id} : #{r_emply.emply_code}:#{r_emply.lst_name}#{r_emply.frst_name}" if @debug_prt
            cur_usr_idx = cnt_idx
            @cur_usr_name = ApplicationHelper.nrrw_emply_name_with_code(r_emply.emply_code, r_emply.lst_name, r_emply.frst_name, nil, max_name_length)
          else
          # p "[get_pager_emply_ids] NOHIT : #{@usr.select_usr_id} != #{r_emply.usr_id} : #{r_emply.emply_code}:#{r_emply.lst_name}#{r_emply.frst_name}" if @debug_prt
          end
          cnt_idx += 1
        end
        if cur_usr_idx == 0 then
          if "#{sql_prmtr[:page]}".to_i > 1 then
            sql_prmtr[:page] = "#{sql_prmtr[:page]}".to_i - 1
            rs_emply_prev = MEmply.get_emply_list(sql_prmtr)
            if rs_emply_prev && rs_emply_prev.length > 0 then
              i = rs_emply_prev.length-1
              @prev_usr_id  = rs_emply_prev[i].usr_id
              @prev_sctn_id = rs_emply_prev[i].sctn_id
              @prev_ebtm_id = rs_emply_prev[i].ebtm_id
              @prev_slp_code = rs_emply_prev[i].emplymnt_cntrct_slp_code
              @prev_usr_name = ApplicationHelper.nrrw_emply_name_with_code(rs_emply_prev[i].emply_code, rs_emply_prev[i].lst_name, rs_emply_prev[i].frst_name, nil, max_name_length)
              @cndtn[:page_dec_usr_id] = @prev_usr_id
            # p "[get_pager_emply_ids] 1 i(#{i}) @prev_usr_id(#{@prev_usr_id}) @prev_slp_code(#{@prev_slp_code}) @prev_usr_name(#{@prev_usr_name})" if @debug_prt
            end
          end
        else
          i = cur_usr_idx - 1
          if ary_emply && ary_emply[i] && ary_emply[i].usr_id then
            @prev_usr_id = ary_emply[i].usr_id
            @prev_sctn_id = ary_emply[i].sctn_id
            @prev_ebtm_id = ary_emply[i].ebtm_id
            @prev_slp_code = ary_emply[i].emplymnt_cntrct_slp_code
            @prev_usr_name = ApplicationHelper.nrrw_emply_name_with_code(ary_emply[i].emply_code, ary_emply[i].lst_name, ary_emply[i].frst_name, nil, max_name_length)
          else
            $cmmnlog.inf_log("[EcmEmplySelectModule.get_pager_emply_ids] 2 rs_emply.length(#{rs_emply.length}) ary_emply[#{i}] == nil : ary_emply = #{ary_emply.inspect}")
          end
        # p "[get_pager_emply_ids] 2 i(#{i}) @prev_usr_id(#{@prev_usr_id}) @prev_slp_code(#{@prev_slp_code}) @prev_usr_name(#{@prev_usr_name})" if @debug_prt
        end
        if cur_usr_idx == rs_emply.length - 1 then
          if rs_emply.length >= "#{@usr.max_list_size}".to_i then
            sql_prmtr[:page] = "#{sql_prmtr[:page]}".to_i + 1
            rs_emply_next = MEmply.get_emply_list(sql_prmtr)
            if rs_emply_next && rs_emply_next.length > 0 then
              i = 0
              @next_usr_id = rs_emply_next[i].usr_id
              @next_sctn_id = rs_emply_next[i].sctn_id
              @next_ebtm_id = rs_emply_next[i].ebtm_id
              @next_slp_code = rs_emply_next[i].emplymnt_cntrct_slp_code
              @next_usr_name = ApplicationHelper.nrrw_emply_name_with_code(rs_emply_next[i].emply_code, rs_emply_next[i].lst_name, rs_emply_next[i].frst_name, nil, max_name_length)
              @cndtn[:page_inc_usr_id] = @next_usr_id
            # p "[get_pager_emply_ids] 3 i(#{i}) @next_usr_id(#{@next_usr_id}) @next_slp_code(#{@next_slp_code}) @next_usr_name(#{@next_usr_name})" if @debug_prt
            end
          end
        else
          i = cur_usr_idx + 1
          if ary_emply && ary_emply[i] && ary_emply[i].usr_id then
            @next_usr_id = ary_emply[i].usr_id
            @next_sctn_id = ary_emply[i].sctn_id
            @next_ebtm_id = ary_emply[i].ebtm_id
            @next_slp_code = ary_emply[i].emplymnt_cntrct_slp_code
            @next_usr_name = ApplicationHelper.nrrw_emply_name_with_code(ary_emply[i].emply_code, ary_emply[i].lst_name, ary_emply[i].frst_name, nil, max_name_length)
          else
            $cmmnlog.inf_log("[EcmEmplySelectModule.get_pager_emply_ids] 4 rs_emply.length(#{rs_emply.length}) ary_emply[#{i}] == nil : ary_emply = #{ary_emply.inspect}")
          end
        # p "[get_pager_emply_ids] 4 i(#{i}) @next_usr_id(#{@next_usr_id}) @next_slp_code(#{@next_slp_code}) @next_usr_name(#{@next_usr_name})" if @debug_prt
        end
      end
    end
    @t_prev = cur_usr_ids.include?(@prev_usr_id)
    @t_next = cur_usr_ids.include?(@next_usr_id)
  # if @debug_prt then
    # p "[get_pager_emply_ids] <<@prev_usr_id=#{@prev_usr_id} usr_id=#{@usr.select_usr_id}(idx=#{cur_usr_idx}) @next_usr_id=#{@next_usr_id}>>"
    # p "[get_pager_emply_ids] <<#{@prev_usr_name} #{@cur_usr_name} #{@next_usr_name}>>"
  # end
  end

  def set_ebtm_id
    ebtm = MEmplyBlngToMngmnt.today_main_or_tail_main(@ectm)

    if @cndtn[:tgt_usr_id] != @ectm.usr_id then
      @cndtn[:tgt_usr_id] = @ectm.usr_id
      @cndtn[:select_ebtm_id] = ebtm ? ebtm.id.to_s : ""
    end
    @cndtn[:select_ebtm_id] = @usr.select_ebtm_id
    @cndtn[:select_ebtm_id] = params[:cndtn][:select_ebtm_id].to_i if params[:cndtn]
    hstry_sctn_hash = MEmplyBlngToMngmnt.hstry_sctn_hash(@ectm)
    unless hstry_sctn_hash[@cndtn[:select_ebtm_id].to_i] then
      @cndtn[:select_ebtm_id] = ebtm ? ebtm.id.to_s : ""
    end

    @cndtn[:select_ebtm_id] = params[:usr_sctn_id].split(" ")[1] if !params[:usr_sctn_id].blank?
    @ebtm = hstry_sctn_hash[@cndtn[:select_ebtm_id].to_i]
    if @ebtm then
      @usr.select_ebtm_id = @ebtm.id
      @usr.select_sctn_id ||= @ebtm.sctn_id.to_i
      if @ebtm.sctn_id != @usr.select_sctn_id then
        @usr.select_sctn_id = @ebtm.sctn_id.to_i
      end
    else
      @usr.select_ebtm_id = nil
      flash[:warning] = "選択した期間内に所属部署がありません。"

      @ebtm = nil
      @not_cntrct_err = true
      @models = []
      render :action => @cndtn[:redirect_page]
      return false
    end
    return true
  end

  def cck_role
    unless @usr.srvs_usr?(2, Cnst::PckgName::WORK) then
      render_sstm_err(Cnst::ROLE_CCK_ERR)
    end
  end

end