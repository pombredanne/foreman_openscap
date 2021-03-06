require 'test_plugin_helper'

class Api::V2::Compliance::PoliciesControllerTest < ActionController::TestCase
  setup do
    ::ForemanOpenscap::Policy.any_instance.stubs(:ensure_needed_puppetclasses).returns(true)
    @scap_content_profile = FactoryBot.create(:scap_content_profile)
    @attributes = { :policy => { :name => 'my_policy',
                                 :scap_content_profile_id => @scap_content_profile.id,
                                 :scap_content_id => @scap_content_profile.scap_content_id,
                                 :period => 'weekly',
                                 :weekday => 'friday' } }
  end

  test "should get index" do
    FactoryBot.create(:policy)
    get :index, {}, set_session_user
    response = ActiveSupport::JSON.decode(@response.body)
    assert !response['results'].empty?
    assert_response :success
  end

  test "should show a policy" do
    policy = FactoryBot.create(:policy)
    get :show, { :id => policy.to_param }, set_session_user
    response = ActiveSupport::JSON.decode(@response.body)
    assert response['name'], policy.name
    assert_response :success
  end

  test "should update a policy" do
    policy = FactoryBot.create(:policy)
    put :update, { :id => policy.id, :policy => { :period => 'monthly', :day_of_month => 15 } }
    updated_policy = ActiveSupport::JSON.decode(@response.body)
    assert(updated_policy['period'], 'monthly')
    assert_response :ok
  end

  test "should not update invalid" do
    policy = FactoryBot.create(:policy)
    put :update, { :id => policy.id, :policy => { :name => '' } }
    assert_response :unprocessable_entity
  end

  test "should create a policy" do
    post :create, @attributes, set_session_user
    response = ActiveSupport::JSON.decode(@response.body)
    assert response['scap_content_profile_id'], @scap_content_profile.to_param
    assert_response :created
  end

  test "should not create a policy with tailoring file profile and without the actual file" do
    tailoring_profile = FactoryBot.create(:scap_content_profile, :profile_id => 'xccdf_org.test.tailoring_profile')
    @attributes[:policy][:tailoring_file_profile_id] = tailoring_profile.id
    post :create, @attributes, set_session_user
    response = ActiveSupport::JSON.decode(@response.body)
    assert_not_nil response['error']['errors']['tailoring_file_id']
    assert_response :unprocessable_entity
  end

  test "should not create a policy with tailoring file and without tailoring profile" do
    tailoring_file = FactoryBot.create(:tailoring_file)
    @attributes[:policy][:tailoring_file_id] = tailoring_file.id
    post :create, @attributes, set_session_user
    response = ActiveSupport::JSON.decode(@response.body)
    assert_not_nil response['error']['errors']['tailoring_file_profile_id']
    assert_response :unprocessable_entity
  end

  test "should not create invalid policy" do
    post :create, {}, set_session_user
    assert_response :unprocessable_entity
  end

  test "should destroy" do
    policy = FactoryBot.create(:policy)
    delete :destroy, { :id => policy.id }, set_session_user
    assert_response :ok
    refute ForemanOpenscap::Policy.exists?(policy.id)
  end

  test "should return xml of scap content" do
    policy = FactoryBot.create(:policy)
    get :content, { :id => policy.id }, set_session_user
    assert(@response.header['Content-Type'], 'application/xml')
    assert_response :success
  end

  test "should return xml of a tailoring file" do
    tailoring_profile = FactoryBot.create(:scap_content_profile)
    policy = FactoryBot.create(:policy, :tailoring_file => FactoryBot.create(:tailoring_file, :scap_content_profiles => [tailoring_profile]),
                                        :tailoring_file_profile => tailoring_profile)
    get :tailoring, { :id => policy.id }, set_session_user
    assert(@response.header['Content-Type'], 'application/xml')
    assert_response :success
  end

  test "should return meaningufull error when no tailioring file assigned" do
    policy = FactoryBot.create(:policy)
    get :tailoring, { :id => policy.id }, set_session_user
    assert_response :not_found
    response = ActiveSupport::JSON.decode(@response.body)
    assert_equal "No Tailoring file assigned for policy with id #{policy.id}", response['error']['message']
  end
end
