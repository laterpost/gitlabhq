# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchHelper do
  include MarkupHelper

  # Override simple_sanitize for our testing purposes
  def simple_sanitize(str)
    str
  end

  describe 'search_autocomplete_opts' do
    context "with no current user" do
      before do
        allow(self).to receive(:current_user).and_return(nil)
      end

      it "returns nil" do
        expect(search_autocomplete_opts("q")).to be_nil
      end
    end

    context "with a standard user" do
      let(:user) { create(:user) }

      before do
        allow(self).to receive(:current_user).and_return(user)
      end

      it "includes Help sections" do
        expect(search_autocomplete_opts("hel").size).to eq(8)
      end

      it "includes default sections" do
        expect(search_autocomplete_opts("dash").size).to eq(1)
      end

      it "does not include admin sections" do
        expect(search_autocomplete_opts("admin").size).to eq(0)
      end

      it "does not allow regular expression in search term" do
        expect(search_autocomplete_opts("(webhooks|api)").size).to eq(0)
      end

      it "includes the user's groups" do
        create(:group).add_owner(user)
        expect(search_autocomplete_opts("gro").size).to eq(1)
      end

      it "includes nested group" do
        create(:group, :nested, name: 'foo').add_owner(user)
        expect(search_autocomplete_opts('foo').size).to eq(1)
      end

      it "includes the user's projects" do
        project = create(:project, namespace: create(:namespace, owner: user))
        expect(search_autocomplete_opts(project.name).size).to eq(1)
      end

      it "includes the required project attrs" do
        project = create(:project, namespace: create(:namespace, owner: user))
        result = search_autocomplete_opts(project.name).first

        expect(result.keys).to match_array(%i[category id value label url avatar_url])
      end

      it "includes the required group attrs" do
        create(:group).add_owner(user)
        result = search_autocomplete_opts("gro").first

        expect(result.keys).to match_array(%i[category id label url avatar_url])
      end

      it 'includes the users recently viewed issues' do
        recent_issues = instance_double(::Gitlab::Search::RecentIssues)
        expect(::Gitlab::Search::RecentIssues).to receive(:new).with(user: user).and_return(recent_issues)
        project1 = create(:project, :with_avatar, namespace: user.namespace)
        project2 = create(:project, namespace: user.namespace)
        issue1 = create(:issue, title: 'issue 1', project: project1)
        issue2 = create(:issue, title: 'issue 2', project: project2)

        expect(recent_issues).to receive(:search).with('the search term').and_return(Issue.id_in_ordered([issue1.id, issue2.id]))

        results = search_autocomplete_opts("the search term")

        expect(results.count).to eq(2)

        expect(results[0]).to include({
          category: 'Recent issues',
          id: issue1.id,
          label: 'issue 1',
          url: Gitlab::Routing.url_helpers.project_issue_path(issue1.project, issue1),
          avatar_url: project1.avatar_url
        })

        expect(results[1]).to include({
          category: 'Recent issues',
          id: issue2.id,
          label: 'issue 2',
          url: Gitlab::Routing.url_helpers.project_issue_path(issue2.project, issue2),
          avatar_url: '' # This project didn't have an avatar so set this to ''
        })
      end

      it 'includes the users recently viewed merge requests' do
        recent_merge_requests = instance_double(::Gitlab::Search::RecentMergeRequests)
        expect(::Gitlab::Search::RecentMergeRequests).to receive(:new).with(user: user).and_return(recent_merge_requests)
        project1 = create(:project, :with_avatar, namespace: user.namespace)
        project2 = create(:project, namespace: user.namespace)
        merge_request1 = create(:merge_request, :unique_branches, title: 'Merge request 1', target_project: project1, source_project: project1)
        merge_request2 = create(:merge_request, :unique_branches, title: 'Merge request 2', target_project: project2, source_project: project2)

        expect(recent_merge_requests).to receive(:search).with('the search term').and_return(MergeRequest.id_in_ordered([merge_request1.id, merge_request2.id]))

        results = search_autocomplete_opts("the search term")

        expect(results.count).to eq(2)

        expect(results[0]).to include({
          category: 'Recent merge requests',
          id: merge_request1.id,
          label: 'Merge request 1',
          url: Gitlab::Routing.url_helpers.project_merge_request_path(merge_request1.project, merge_request1),
          avatar_url: project1.avatar_url
        })

        expect(results[1]).to include({
          category: 'Recent merge requests',
          id: merge_request2.id,
          label: 'Merge request 2',
          url: Gitlab::Routing.url_helpers.project_merge_request_path(merge_request2.project, merge_request2),
          avatar_url: '' # This project didn't have an avatar so set this to ''
        })
      end

      it "does not include the public group" do
        group = create(:group)
        expect(search_autocomplete_opts(group.name).size).to eq(0)
      end

      context "with a current project" do
        before do
          @project = create(:project, :repository)
        end

        it "includes project-specific sections" do
          expect(search_autocomplete_opts("Files").size).to eq(1)
          expect(search_autocomplete_opts("Commits").size).to eq(1)
        end
      end
    end

    context 'with an admin user' do
      let(:admin) { create(:admin) }

      before do
        allow(self).to receive(:current_user).and_return(admin)
      end

      it "includes admin sections" do
        expect(search_autocomplete_opts("admin").size).to eq(1)
      end
    end
  end

  describe 'search_entries_info' do
    using RSpec::Parameterized::TableSyntax

    where(:scope, :label) do
      'blobs'          | 'code result'
      'commits'        | 'commit'
      'issues'         | 'issue'
      'merge_requests' | 'merge request'
      'milestones'     | 'milestone'
      'notes'          | 'comment'
      'projects'       | 'project'
      'snippet_titles' | 'snippet'
      'users'          | 'user'
      'wiki_blobs'     | 'wiki result'
    end

    with_them do
      it 'uses the correct singular label' do
        collection = Kaminari.paginate_array([:foo]).page(1).per(10)

        expect(search_entries_info(collection, scope, 'foo')).to eq("Showing 1 #{label} for<span>&nbsp;<code>foo</code>&nbsp;</span>")
      end

      it 'uses the correct plural label' do
        collection = Kaminari.paginate_array([:foo] * 23).page(1).per(10)

        expect(search_entries_info(collection, scope, 'foo')).to eq("Showing 1 - 10 of 23 #{label.pluralize} for<span>&nbsp;<code>foo</code>&nbsp;</span>")
      end
    end

    it 'raises an error for unrecognized scopes' do
      expect do
        collection = Kaminari.paginate_array([:foo]).page(1).per(10)
        search_entries_info(collection, 'unknown', 'foo')
      end.to raise_error(RuntimeError)
    end
  end

  describe 'search_entries_empty_message' do
    it 'returns the formatted entry message' do
      message = search_entries_empty_message('projects', '<h1>foo</h1>')

      expect(message).to eq("We couldn't find any projects matching <code>&lt;h1&gt;foo&lt;/h1&gt;</code>")
      expect(message).to be_html_safe
    end
  end

  describe 'search_filter_input_options' do
    context 'project' do
      before do
        @project = create(:project, :repository)
      end

      it 'includes id with type' do
        expect(search_filter_input_options('type')[:id]).to eq('filtered-search-type')
      end

      it 'includes project-id' do
        expect(search_filter_input_options('')[:data]['project-id']).to eq(@project.id)
      end

      it 'includes project endpoints' do
        expect(search_filter_input_options('')[:data]['runner-tags-endpoint']).to eq(tag_list_admin_runners_path)
        expect(search_filter_input_options('')[:data]['labels-endpoint']).to eq(project_labels_path(@project))
        expect(search_filter_input_options('')[:data]['milestones-endpoint']).to eq(project_milestones_path(@project))
        expect(search_filter_input_options('')[:data]['releases-endpoint']).to eq(project_releases_path(@project))
      end

      it 'includes autocomplete=off flag' do
        expect(search_filter_input_options('')[:autocomplete]).to eq('off')
      end
    end

    context 'group' do
      before do
        @group = create(:group, name: 'group')
      end

      it 'does not includes project-id' do
        expect(search_filter_input_options('')[:data]['project-id']).to eq(nil)
      end

      it 'includes group endpoints' do
        expect(search_filter_input_options('')[:data]['runner-tags-endpoint']).to eq(tag_list_admin_runners_path)
        expect(search_filter_input_options('')[:data]['labels-endpoint']).to eq(group_labels_path(@group))
        expect(search_filter_input_options('')[:data]['milestones-endpoint']).to eq(group_milestones_path(@group))
      end
    end

    context 'dashboard' do
      it 'does not include group-id and project-id' do
        expect(search_filter_input_options('')[:data]['project-id']).to eq(nil)
        expect(search_filter_input_options('')[:data]['group-id']).to eq(nil)
      end

      it 'includes dashboard endpoints' do
        expect(search_filter_input_options('')[:data]['runner-tags-endpoint']).to eq(tag_list_admin_runners_path)
        expect(search_filter_input_options('')[:data]['labels-endpoint']).to eq(dashboard_labels_path)
        expect(search_filter_input_options('')[:data]['milestones-endpoint']).to eq(dashboard_milestones_path)
      end
    end
  end

  describe 'search_history_storage_prefix' do
    context 'project' do
      it 'returns project full_path' do
        @project = create(:project, :repository)

        expect(search_history_storage_prefix).to eq(@project.full_path)
      end
    end

    context 'group' do
      it 'returns group full_path' do
        @group = create(:group, :nested, name: 'group-name')

        expect(search_history_storage_prefix).to eq(@group.full_path)
      end
    end

    context 'dashboard' do
      it 'returns dashboard' do
        expect(search_history_storage_prefix).to eq("dashboard")
      end
    end
  end

  describe 'search_md_sanitize' do
    it 'does not do extra sql queries for partial markdown rendering' do
      @project = create(:project)

      description = FFaker::Lorem.characters(210)
      control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) { search_md_sanitize(description) }.count

      issues = create_list(:issue, 4, project: @project)

      description_with_issues = description + ' ' + issues.map { |issue| "##{issue.iid}" }.join(' ')
      expect { search_md_sanitize(description_with_issues) }.not_to exceed_all_query_limit(control_count)
    end
  end

  describe 'search_filter_link' do
    it 'renders a search filter link for the current scope' do
      @scope = 'projects'
      @search_results = double

      expect(@search_results).to receive(:formatted_count).with('projects').and_return('23')

      link = search_filter_link('projects', 'Projects')

      expect(link).to have_css('li.active')
      expect(link).to have_link('Projects', href: search_path(scope: 'projects'))
      expect(link).to have_css('span.badge.badge-pill:not(.js-search-count):not(.hidden):not([data-url])', text: '23')
    end

    it 'renders a search filter link for another scope' do
      link = search_filter_link('projects', 'Projects')
      count_path = search_count_path(scope: 'projects')

      expect(link).to have_css('li:not([class="active"])')
      expect(link).to have_link('Projects', href: search_path(scope: 'projects'))
      expect(link).to have_css("span.badge.badge-pill.js-search-count.hidden[data-url='#{count_path}']", text: '')
    end

    it 'merges in the current search params and given params' do
      expect(self).to receive(:params).and_return(
        ActionController::Parameters.new(
          search: 'hello',
          scope: 'ignored',
          other_param: 'ignored'
        )
      )

      link = search_filter_link('projects', 'Projects', search: { project_id: 23 })

      expect(link).to have_link('Projects', href: search_path(scope: 'projects', search: 'hello', project_id: 23))
    end

    it 'assigns given data attributes on the list container' do
      link = search_filter_link('projects', 'Projects', data: { foo: 'bar' })

      expect(link).to have_css('li[data-foo="bar"]')
    end
  end

  describe '#show_user_search_tab?' do
    subject { show_user_search_tab? }

    context 'when project search' do
      before do
        @project = :some_project

        expect(self).to receive(:project_search_tabs?)
          .with(:members)
          .and_return(:value)
      end

      it 'delegates to project_search_tabs?' do
        expect(subject).to eq(:value)
      end
    end

    context 'when not project search' do
      context 'when current_user can read_users_list' do
        before do
          allow(self).to receive(:current_user).and_return(:the_current_user)
          allow(self).to receive(:can?).with(:the_current_user, :read_users_list).and_return(true)
        end

        it { is_expected.to eq(true) }
      end

      context 'when current_user cannot read_users_list' do
        before do
          allow(self).to receive(:current_user).and_return(:the_current_user)
          allow(self).to receive(:can?).with(:the_current_user, :read_users_list).and_return(false)
        end

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#repository_ref' do
    let_it_be(:project) { create(:project, :repository) }
    let(:params) { { repository_ref: 'the-repository-ref-param' } }

    subject { repository_ref(project) }

    it { is_expected.to eq('the-repository-ref-param') }

    context 'when the param :repository_ref is not set' do
      let(:params) { { repository_ref: nil } }

      it { is_expected.to eq(project.default_branch) }
    end

    context 'when the repository_ref param is a number' do
      let(:params) { { repository_ref: 111111 } }

      it { is_expected.to eq('111111') }
    end
  end

  describe '#highlight_and_truncate_issue' do
    let(:description) { 'hello world' }
    let(:issue) { create(:issue, description: description) }
    let(:user) { create(:user) }

    before do
      allow(self).to receive(:current_user).and_return(user)
    end

    subject { highlight_and_truncate_issue(issue, 'test', {}) }

    context 'when description is not present' do
      let(:description) { nil }

      it 'does nothing' do
        expect(self).not_to receive(:simple_search_highlight_and_truncate)

        subject
      end
    end

    context 'when description present' do
      using RSpec::Parameterized::TableSyntax

      where(:description, :expected) do
        'test'                                                                 | '<span class="gl-text-black-normal gl-font-weight-bold">test</span>'
        '<span style="color: blue;">this test should not be blue</span>'       | '<span>this <span class="gl-text-black-normal gl-font-weight-bold">test</span> should not be blue</span>'
        '<a href="#" onclick="alert(\'XSS\')">Click Me test</a>'               | '<a href="#">Click Me <span class="gl-text-black-normal gl-font-weight-bold">test</span></a>'
        '<script type="text/javascript">alert(\'Another XSS\');</script> test' | ' <span class="gl-text-black-normal gl-font-weight-bold">test</span>'
        'Lorem test ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec.' | 'Lorem <span class="gl-text-black-normal gl-font-weight-bold">test</span> ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Don...'
      end

      with_them do
        it 'sanitizes, truncates, and highlights the search term' do
          expect(subject).to eq(expected)
        end
      end
    end
  end

  describe '#search_service' do
    using RSpec::Parameterized::TableSyntax

    subject { search_service }

    before do
      allow(self).to receive(:current_user).and_return(:the_current_user)
    end

    where(:confidential, :expected) do
      '0'       | false
      '1'       | true
      'yes'     | true
      'no'      | false
      true      | true
      false     | false
    end

    let(:params) {{ confidential: confidential }}

    with_them do
      it 'transforms confidentiality param' do
        expect(::SearchService).to receive(:new).with(:the_current_user, { confidential: expected })

        subject
      end
    end
  end
end
