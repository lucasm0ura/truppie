require 'test_helper'

class ContactsControllerTest < ActionController::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end
  
  test "should post send_form with no params raise flash error" do
    params_empty = {:name => '',:subject => '', :email => '', :body => ''}
    post :send_form, params_empty
    assert_equal 'Faltou preencher o email e/ou a mensagem', flash[:error]
    assert_redirected_to contacts_index_path
    assert_equal ActionMailer::Base.deliveries.empty?, true
  end
  
  test "should post send_form and send a email with all fields required filled" do
    params = {:name => 'Alexandre Magno',:subject => "opinion", :email => 'alexanmtz@gmail.com', :body => 'hi'}
    post :send_form, params
    assert_equal 'Sua mensagem foi enviada com sucesso, entraremos em contato em breve', flash[:success]
    assert_redirected_to contacts_index_path
    assert_not ActionMailer::Base.deliveries.empty?
  end
  
 
end
