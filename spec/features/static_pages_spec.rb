require 'spec_helper'

describe "StaticPages" do

  subject { page }

  describe "Splash Page" do

    before { visit root_path }

    it "should have a title" do
      # save_and_open_page
      subject.source.should have_selector('title', text: "Odin") 
    end
    it "should hide the navbar" do
      page.should have_css('#top-navbar', :visible => false)
    end

    it { should have_selector('h1', text: "Become") }
    it { should_not have_link "Scheduler" }
    it { should have_link "", href: "http://www.github.com/TheOdinProject/curriculum" }
    it { should have_link '...Or sign up for our private alpha offering HERE', :href => splash_email_path }
  end

  describe "Splash Email Page" do

    before { visit splash_email_path }

    describe "filling in the email form" do
      before(:each) do
        fill_in("splash_email_email", with: "foo@bar.com")
      end

      it "should create the splash_email instance" do
        expect { click_button("commit") }.to change(SplashEmail, :count).by(1)
      end

      describe "after form submission" do
        before(:each) do
          click_button("commit")
        end

        it "should redirect to the thank_you page" do
          subject.should have_selector('h3', text: "Thanks!")
        end
      end
    end
  end

  describe "Splash Thank You Page" do

    before { visit thank_you_path }

    it { should have_selector('h3', text: "Thanks!") }

  end

  describe "Scheduler Page" do

    let(:suggestion_body) { "suggestionforyou" }

    before { visit scheduler_path }

    context "as an unauthenticated user" do
      
      it { should have_selector('h2', "Sign in") }
      it { should have_css('form#footer-suggestion-form') }

    end

    context "after authenticating" do

      let(:user) { FactoryGirl.create(:user) }

      before do
        sign_in(user)
        visit scheduler_path
      end

      it { should have_selector('h1', :text => "Start Programming Together") }
      it { should have_css('form#footer-suggestion-form') }

      context "before user chooses a project" do
        it "should have a prompt to choose a project" do
          subject.should have_selector("p.warning", "Tip:")
        end
        it "should not have a change project link" do
          subject.should_not have_link("edit")
        end
      end
      context "after user chooses a project" do
        before do
          cb = FactoryGirl.create(:content_bucket)
          user.content_buckets << cb
          user.save!
          visit current_path
        end
        it "should have a change project link" do
          subject.should have_link("edit")
        end
        it "should not have a prompt to choose a project" do
          subject.should_not have_selector("p.warning", "Tip:")
        end
      end

      describe "filling in the suggestion form" do
        before(:each) do
          ActionMailer::Base.deliveries = []  # Clear out other test deliveries
          # save_and_open_page
          fill_in("suggestion", with: suggestion_body)
        end

        context "after submitting the form" do
          before(:each) do
            click_button("suggestion-button")
          end
            
          it "should send an email request with the form contents" do
            ActionMailer::Base.deliveries.first.encoded.should include suggestion_body
          end
        end
      end

      # Commenting these out because they require Javascript tests!
      # it { should have_selector("th", :text => "11am" ) }
      # it { should have_selector("span", :text => "today" ) }

      # it "should default to week view" do
      #   save_and_open_page
      # #   subject.should have_selector("span", :text => "week", :class => "fc-button-agenda-week")
      
      # end
    end
  end

  describe "User authentication flow" do
    
    let(:user) { FactoryGirl.create(:user) }  
    before { visit home_path }

    describe "should start on the home page" do

      it { should have_selector('h1', :text => "Become a Web Developer") }
      it { should_not have_link "Logout" }

      describe "then click through to login" do

        before { click_link "Login" }

        it { should have_selector('h2', :text => "Sign in") }

        describe "then login to land on the scheduler page" do

          before do
            fill_in "Email", :with => user.email
            fill_in "Password", :with => user.password
            click_button "Sign in"
          end

          it { should have_selector('h1', :text => "Start Programming Together" ) }

          describe "then click logout to sign out to home page" do

            before do
              click_link "Logout"
            end

            it { should have_selector('h1', :text => "Become a Web Developer") }
          end
        end
      end
    end
  end

  describe "referral links" do

    context "for content buckets" do

      let!(:cb) { FactoryGirl.create(:content_bucket) }
      let!(:cb2) { FactoryGirl.create(:content_bucket) }
      let!(:user) { FactoryGirl.create(:user) }

      context "when query string is a valid bucket" do
        before do
          visit home_path(:cb => cb.id)
        end

        context "when user is signed in" do

          before do
            sign_in(user)  # Signing in sends you to scheduler path!
          end

          context "and user has no content buckets" do
            context "when user visits the scheduler page" do
              before do
                visit scheduler_path
              end

              it "creates a new content bucket" do
                user.content_buckets.count.should == 1
              end

            end
          end

          context "and user has non-dupe content buckets already" do
            before do
              user.content_buckets << cb2
            end
            
            context "when user visits the scheduler page" do
              before do
                visit scheduler_path
              end
              it "creates a new content bucket" do
                user.content_buckets.count.should == 2
              end
            end
          end

          context "and user has duplicate buckets already" do
            before do
              # puts "\n\n\n\n\n\n\n User.content_bucekts: #{user.content_buckets}... \n\n\n ...and cb is #{cb.inspect}... \n\n\n and user is #{user.inspect}! \n\n\n\n\n\n\n"
              # THS WILL FAIL as long as the default path after signin is the scheduler, since that will automatically activate the creation of the cb bucket prior to running this code!
              user.content_buckets << cb
            end

            context "and visits the scheduler page" do
              before do
                visit scheduler_path
              end

              it "does not create a new content bucket WILL FAIL, SEE NOTE" do
                user.content_buckets.count.should == 1
              end
            end
          end   
        end
      end

      context "when query string is NOT a valid bucket" do
        before do
          visit home_path(:cb => 9999999)
        end

        context "when user is signed in" do

          before do
            sign_in(user)  # Signing in sends you to scheduler path!
          end

          context "and user has no prior content buckets" do
            context "when user visits the scheduler page" do
              before do
                visit scheduler_path
              end

              it "does NOT create a new content bucket" do
                user.content_buckets.count.should == 0
              end
            end
          end
        end
      end
    end
  end

  describe "user preferences" do
    let(:user){ FactoryGirl.create(:user) }

    before do
      sign_in(user)
      visit scheduler_path
      click_link "Preferences"
    end

    it "sends user back to referring URL" do
      click_button "Update"
      current_path.should == scheduler_path
    end

  end
end







